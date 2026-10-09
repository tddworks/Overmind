import Measures

/// A chart or list on a service's tab: where a limit's use came from (ENGINE_DESIGN §4).
public struct BreakdownDefinition: Sendable, Equatable {
    public let title: String
    public let kind: Kind

    public enum Kind: Sendable, Equatable {
        /// Bars over time for one of the service's limits, with deployment pins.
        case series(limit: LimitID, by: Step, last: Int)
        /// A ranked list: queries by rows read.
        case top(dataset: String, dimension: String, measure: String, count: Int, time: TimeFilter)
        /// One row per value of a dimension: invocations by status.
        case split(dataset: String, dimension: String, measure: String, time: TimeFilter)
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
    private struct Top: Decodable { let dataset, dimension, measure: String; let count: Int; let time: TimeFilter }
    private struct Split: Decodable { let dataset, dimension, measure: String; let time: TimeFilter }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        title = try container.decode(String.self, forKey: .title)
        if let series = try container.decodeIfPresent(Series.self, forKey: .series) {
            kind = .series(limit: series.limit, by: series.by, last: series.last)
        } else if let top = try container.decodeIfPresent(Top.self, forKey: .top) {
            kind = .top(dataset: top.dataset, dimension: top.dimension, measure: top.measure, count: top.count, time: top.time)
        } else if let split = try container.decodeIfPresent(Split.self, forKey: .split) {
            kind = .split(dataset: split.dataset, dimension: split.dimension, measure: split.measure, time: split.time)
        } else {
            throw DefinitionError.unknownCase("breakdown “\(title)” must be a series, top or split")
        }
    }
}
