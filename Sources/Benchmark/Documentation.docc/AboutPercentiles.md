# About Percentiles

About percentiles and how to interpret them.

## Overview

The default text output from Benchmark is oriented around [the five-number summary](https://en.wikipedia.org/wiki/Five-number_summary) percentiles, plus the last decile (`p90`) and the last percentile (`p99`) - it's thus a variation of a [seven-figure summary](https://en.wikipedia.org/wiki/Seven-number_summary) with the focus on the 'bad' end of results (as those are what we typically care about addressing).

We've found that focusing on percentiles rather than average or standard deviations, is more useful for a wider range of benchmark measurements and gives a deeper understanding of the results.
Percentiles allow for a consistent way of expressing benchmark results of both throughput and latency measurements (which typically do **not** have a standardized distribution, being almost always are multi-modal in nature).
This multi-modal nature of the latency measurements leads to the common statistical measures of mean and standard deviation being potentially misleading.

That being said, some of the export formats do include more traditional mean and standard deviation statistics.
The Benchmark infrastructure captures _all_ samples for a test run, so you can review the raw data points for your own post-run statistical analysis if desired. It's recommended that you explore the default output formats and the existing analytical tools first.

### What are Percentiles?

A percentile N, typically denoted pN, is a score at or below which a given percentage of N scores in its frequency distribution falls ([Wikipedia: Percentile](https://en.wikipedia.org/wiki/Percentile)).

For instance, a result of value V measured at percentile p25 means that 25% of all samples are V or lower. The p50 percentile is therefore the same as the [Median](https://en.wikipedia.org/wiki/Median) - the result separating the higher half from the lower half in a data sample.

Two other percentiles are particularly noteworthy:

- p0 is the minimum
- p100 is the maximum

of the data sample.

### Why Percentiles?

It is tempting to think of performance benchmarking as a repeat experiment, whose results can be averaged and for which a standard deviation can be computed to estimate an error margin. However, this is almost never the correct approach, because the results almost never follow a [Gaussian distribution](https://en.wikipedia.org/wiki/Normal_distribution) in practice.

This is very well explained in [Gil Tene's "Understanding Latency" talk](https://www.youtube.com/watch?v=9MKY4KypBzg) where he [dispells the standard deviation](https://www.youtube.com/watch?v=9MKY4KypBzg&t=833s) by showing what actual systems' latency behaviour looks like and how they practically never resemble the normal distribution. Note that while this presentation talks about "latency" this applies not just to latency in the networking sense but to any performance measurement in general.

They _can_ be normally distributed but in practice rarely or never are. This is why using percentiles to describe the shape of a distribution is more generally applicable.

Plotting the full range of percentiles for a measurement, which can be done by [exporting the benchmarks](doc:ExportingBenchmarks), shows the distribution:

![Percentile plot example](PercentileHistogramExample)

The default representation of the Seven-number summary in the measurement table pulls out seven points of this distribution in an attempt to create a simple characterization of it.

### Interpreting results

In order to interpret results it is important to consider your requirements. As you move to the right on the x-axis of the percentile distribution, results will occurr increasingly less frequently. However, do not be tempted to ignore the highest percentiles, because even rare events will happen, in particular in systems with frequent transactions, and slow performance can have disastrous impact on the system when they occur.
