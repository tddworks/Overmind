import Measures

/// A chart or list on a service's tab: where a limit's use came from (ENGINE_DESIGN §4).
public struct BreakdownDefinition: Sendable, Equatable {
    public let title: String
    public let kind: Kind

    public enum Kind: Sendable, Equatable {
        /// Bars over time for one of the service's limits, with deployment pins.
        case series(limit: LimitID, by: Step, last: Int)
        /// A ranked list: queries by rows read.
        case top(Source, dimension: String, count: Int)
        /// One row per value of a dimension: invocations by status. A `measure` of `rows`
        /// counts the rows of a raw dataset (cron runs) instead of adding a field up.
        case split(Source, dimension: String)
    }

    /// Where a list's numbers are: a dataset, the measure, its time filter, and the dimension
    /// the focus narrows it by.
    public struct Source: Sendable, Equatable, Decodable {
        public let dataset: String
        public let measure: String
        public let time: TimeFilter
        public let focus: String?

        public init(dataset: String, measure: String, time: TimeFilter, focus: String? = nil) {
            self.dataset = dataset
            self.measure = measure
            self.time = time
            self.focus = focus
        }

        /// A raw dataset has no groups to add up; its rows are counted.
        public var countsRows: Bool { measure == "rows" }
    }

    public enum Step: String, Sendable, Codable { case hour, day }

    public init(title: String, kind: Kind) {
        self.title = title
        self.kind = kind
    }
}

extension BreakdownDefinition: Decodable {
    private enum Keys: String, CodingKey, CaseIterable { case title, series, top, split }
    private struct Series: Decodable { let limit: LimitID; let by: Step; let last: Int }
    private struct Top: Decodable {
        let dataset, dimension, measure: String; let count: Int; let time: TimeFilter; let focus: String?
    }
    private struct Split: Decodable { let dataset, dimension, measure: String; let time: TimeFilter; let focus: String? }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        title = try container.decode(String.self, forKey: .title)
        if let series = try container.decodeIfPresent(Series.self, forKey: .series) {
            kind = .series(limit: series.limit, by: series.by, last: series.last)
        } else if let top = try container.decodeIfPresent(Top.self, forKey: .top) {
            kind = .top(Source(dataset: top.dataset, measure: top.measure, time: top.time, focus: top.focus),
                        dimension: top.dimension, count: top.count)
        } else if let split = try container.decodeIfPresent(Split.self, forKey: .split) {
            kind = .split(Source(dataset: split.dataset, measure: split.measure, time: split.time, focus: split.focus),
                          dimension: split.dimension)
        } else {
            throw DefinitionError.unknownCase("breakdown “\(title)” must be a series, top or split")
        }
    }
}
