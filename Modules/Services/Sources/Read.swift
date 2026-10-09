/// How a limit's number is found in Cloudflare's analytics (ENGINE_DESIGN §2). A closed sum:
/// a definition file can only use these cases, and a new one is a design change.
public enum Read: Sendable, Equatable {
    /// Add a field up over the period: rows read, requests.
    case sum(Source)
    /// The largest value in the period: storage.
    case max(Source)
    /// A percentile over the period, plus a count of invocations that failed the allowance: CPU.
    case quantile(Source)

    public var source: Source {
        switch self {
        case .sum(let source), .max(let source), .quantile(let source): source
        }
    }

    /// Where the number sits: a dataset, a path in its group, the time filter it takes.
    public struct Source: Sendable, Equatable, Codable {
        public let dataset: String
        public let field: String
        public let time: TimeFilter
        /// The dimension a breakdown narrows by. Never applied to the limit itself (law 1).
        public let focus: String?
        /// What one unit of the answer is worth in the limit's unit: CPU comes in microseconds.
        public let scale: Double?
        /// For a percentile: the invocations that went past the allowance.
        public let failures: Failures?

        public init(dataset: String, field: String, time: TimeFilter, focus: String? = nil,
                    scale: Double? = nil, failures: Failures? = nil) {
            self.dataset = dataset
            self.field = field
            self.time = time
            self.focus = focus
            self.scale = scale
            self.failures = failures
        }
    }

    public struct Failures: Sendable, Equatable, Codable {
        public let dimension: String
        public let equals: String

        public init(dimension: String, equals: String) {
            self.dimension = dimension
            self.equals = equals
        }
    }
}

/// The filter a dataset takes for time: D1 filters by `date`, Workers by `datetime`, D1's
/// query insights by `datetimeHour`.
public enum TimeFilter: String, Sendable, Codable {
    case date, datetime, datetimeHour
}

extension Read: Codable {
    private enum Case: String, CodingKey, CaseIterable { case sum, max, quantile }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Case.self)
        guard container.allKeys.count == 1, let key = container.allKeys.first else {
            throw DefinitionError.unknownCase("a read must be one of \(Case.allCases.map(\.rawValue))")
        }
        let source = try container.decode(Source.self, forKey: key)
        switch key {
        case .sum: self = .sum(source)
        case .max: self = .max(source)
        case .quantile: self = .quantile(source)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Case.self)
        switch self {
        case .sum(let source): try container.encode(source, forKey: .sum)
        case .max(let source): try container.encode(source, forKey: .max)
        case .quantile(let source): try container.encode(source, forKey: .quantile)
        }
    }
}
