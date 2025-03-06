/// A configuration used or expected by a particular result exporter
public protocol BenchmarkExportConfiguration: Codable {}

public struct BenchmarkExportConfigurationKey: Hashable, Codable {
    private let value: String
}

public extension BenchmarkExportConfigurationKey {
    static var influx: Self { .init(value: #function) }
}

/// The set of export configurations for a particular benchmark
public struct BenchmarkExportConfigurations: Codable {
    let configs: [BenchmarkExportConfigurationKey: any BenchmarkExportConfiguration]

    public init(configs: [BenchmarkExportConfigurationKey: any BenchmarkExportConfiguration]) {
        self.configs = configs
    }

    public subscript(_ key: BenchmarkExportConfigurationKey) -> (any BenchmarkExportConfiguration)? {
        configs[key]
    }
}

extension BenchmarkExportConfigurations: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (BenchmarkExportConfigurationKey, any BenchmarkExportConfiguration)...) {
        configs = Dictionary(elements, uniquingKeysWith: { $1 })
    }
}

// N.B. We are clever with the codability implementation below
//  since the value type in `BenchmarkExportConfigurations` is
//  an existential type.
// The key mechanism is `BenchmarkExportConfigurationKey.resolveConfigType`
//  that enables us to determine the appropriate concrete type to
//  attempt to decode based on the key names located in the
//  data container.

extension BenchmarkExportConfigurationKey {
    /// This is used to determine the concrete type to attempt
    /// to decode for a particular ``BenchmarkExportConfigurationKey``
    static func resolveConfigType(from key: Self) -> BenchmarkExportConfiguration.Type? {
        switch key {
        // Add a case here when adding a new exporter config
        case .influx: InfluxExportConfiguration.self
        default: nil
        }
    }
}

public extension BenchmarkExportConfigurations {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: BenchmarkExportConfigurationKey.self)
        self.configs = try container.allKeys.reduce(
            into: [BenchmarkExportConfigurationKey: any BenchmarkExportConfiguration]()
        ) { configs, key in
            if let configType = type(of: key).resolveConfigType(from: key) {
                configs[key] = try container.decode(configType.self, forKey: key)
            }
        }
    }

    func encode(to encoder: any Encoder) throws {
        var encoder = encoder.container(keyedBy: BenchmarkExportConfigurationKey.self)
        for (key, config) in configs {
            try encoder.encode(config, forKey: key)
        }
    }
}

extension BenchmarkExportConfigurationKey: CodingKey {
    public var stringValue: String { value }

    public init?(stringValue: String) { self.init(value: stringValue) }

    public var intValue: Int? { nil }

    public init?(intValue: Int) { nil }
}
