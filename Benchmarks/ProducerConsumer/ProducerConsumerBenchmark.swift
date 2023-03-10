import AsyncAlgorithms
import ConcurrencyHelpers
import BenchmarkSupport
import Foundation
import NIOCore

@main
extension BenchmarkRunner {}

// swiftlint disable: attributes
@_dynamicReplacement(for: registerBenchmarks)
func benchmarks() {
    Benchmark.defaultConfiguration = .init(metrics: [.throughput, .wallClock],
                                           scalingFactor: .mega,
                                           maxDuration: .seconds(1),
                                           maxIterations: .giga(1))

    Benchmark("ProducerConsumer-AsyncStream") { benchmark in
        let (stream, continuation) = {
            typealias Stream = AsyncStream<Int>
            var continuation: Stream.Continuation?
            let stream = Stream(bufferingPolicy: .bufferingOldest(1_000)) { continuation = $0 }
            return (stream, continuation!)
        }()

        benchmark.startMeasurement()

        Task {
            for i in benchmark.scaledIterations {
                await yieldWithBackPressure(message: i, to: continuation)
            }
            continuation.finish()
        }

        let consumer = Task {
            var sum = 0
            for await i in stream {
                sum += i
            }
            return sum
        }

        BenchmarkSupport.blackHole(await consumer.value)
    }

    Benchmark("ProducerConsumer-AsyncChannel") { benchmark in
        let channel = AsyncChannel<Int>()

        benchmark.startMeasurement()

        Task {
            for i in benchmark.scaledIterations {
                await channel.send(i)
            }
            channel.finish()
        }

        let consumer = Task {
            var sum = 0
            for await i in channel {
                sum += i
            }
            return sum
        }

        BenchmarkSupport.blackHole(await consumer.value)
    }

    Benchmark("ProducerConsumer-DispatchQueue") { benchmark in
        let queue = DispatchQueue(label: "test-queue")

        benchmark.startMeasurement()

        var sum = 0

        // producer
        for i in benchmark.scaledIterations {
            queue.async(execute: .init { sum += i })
        }

        BenchmarkSupport.blackHole(queue.sync { sum })
    }

    Benchmark("ProducerConsumer-NIOAsyncSequenceProducer") { benchmark in
        final class Producer: NIOAsyncSequenceProducerDelegate {
            private let rangeToProduce: Range<Int>
            private var producedValue: Int
            private let queue = DispatchQueue(label: "producer-queue")

            var source: NIOAsyncSequenceProducer<Int, NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark, Producer>.Source! = nil

            init(rangeToProduce: Range<Int>) {
                self.rangeToProduce = rangeToProduce
                producedValue = rangeToProduce.lowerBound
            }

            func produceMore() {
                queue.async(execute: .init { self.doProduce() })
            }

            func didTerminate() {
            }

            private func doProduce() {
                while producedValue < rangeToProduce.upperBound {
                    let valueToYield = producedValue
                    producedValue += 1

                    switch source.yield(valueToYield) {
                    case .produceMore:
                        break
                    case .stopProducing:
                        return
                    case .dropped:
                        fatalError("dropped!")
                    }
                }

                source.finish()
            }
        }

        let producer = Producer(rangeToProduce: benchmark.scaledIterations)

        let sequence = NIOAsyncSequenceProducer.makeSequence(
                elementType: Int.self,
                backPressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark(lowWatermark: 500, highWatermark: 1_000),
                delegate: producer)

        producer.source = sequence.source

        benchmark.startMeasurement()

        let consumer = Task {
            var sum = 0
            for await i in sequence.sequence {
                sum += i
            }
            return sum
        }

        BenchmarkSupport.blackHole(await consumer.value)
    }
}
