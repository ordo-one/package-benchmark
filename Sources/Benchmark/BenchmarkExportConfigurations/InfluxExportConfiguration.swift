public struct InfluxExportConfiguration: BenchmarkExportConfiguration {
    /// The set of benchmark tags to interpret as Influx fields.
    /// The default is to treat benchmark tags as Influx tags.
    public let fields: [String: InfluxDataType]

    public enum InfluxDataType: String, Codable {
        // References: https://docs.influxdata.com/influxdb/cloud/reference/syntax/annotated-csv/#data-types

        case boolean
        /// Unsigned 64-bit integer
        case unsignedLong
        /// Signed 64-bit integer
        case long
        /// IEEE-754 64-bit floating-point number
        case double
        /// UTF-8 encoded string
        case string
        /// Base64 encoded sequence of bytes as defined in RFC 4648
        case base64Binary
        /// Instant in time, may be followed with a colon : and a description of the format (number, RFC3339, RFC3339Nano)
        case dateTime
        /// Length of time represented as an unsigned 64-bit integer number of nanoseconds
        case duration
    }

    public init(fields: [String: InfluxDataType]) {
        self.fields = fields
    }
}
