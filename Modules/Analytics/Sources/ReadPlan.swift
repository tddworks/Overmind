import Foundation
import Measures
import Services
import Limits

/// A limit to read, and the period its allowance covers now (nil: what is kept).
public struct LimitRead: Sendable, Equatable {
    public let definition: LimitDefinition
    public let period: Period?

    public init(_ definition: LimitDefinition, period: Period?) {
        self.definition = definition
        self.period = period
    }
}

/// Turns definitions into one GraphQL query per refresh, and its answer back into numbers
/// (TARGET_ARCHITECTURE §3.2). The query is filtered by the account only: `limits` has no
/// focus to pass, so law 1 can't be broken by a caller.
public struct ReadPlan: Sendable {
    public let account: String

    /// How many groups a dataset may answer with; more than a period ever has.
    static let groups = 10_000

    public init(account: String) { self.account = account }

    public func limits(_ reads: [LimitRead], at now: Date) -> PlannedRead {
        var fields: [String] = []
        for (index, read) in reads.enumerated() {
            let source = read.definition.read.source
            let period = read.period ?? .day(containing: now)
            let range = GraphQL.range(source.time, from: period.start, to: min(now, period.end.addingTimeInterval(-1)))
            fields.append("l\(index): \(source.dataset)(limit: \(Self.groups), filter: { \(range) }) { \(GraphQL.selection(source.field)) }")
            if case .quantile(let source) = read.definition.read, let failures = source.failures {
                let filter = "\(range), \(failures.dimension): \(GraphQL.string(failures.equals))"
                fields.append("l\(index)_failures: \(source.dataset)(limit: \(Self.groups), filter: { \(filter) }) { \(GraphQL.selection(failures.measure)) }")
            }
        }
        return PlannedRead(query: query(fields), reads: reads, readAt: now)
    }

    public func breakdowns(_ service: ServiceDefinition, focus: Focus, at now: Date) -> PlannedBreakdowns {
        var fields: [String] = []
        for (index, breakdown) in service.breakdowns.enumerated() {
            let alias = "b\(index)"
            switch breakdown.kind {
            case .series(let limitID, let step, let last):
                guard let limit = service.limits.first(where: { $0.id == limitID }) else { continue }
                let source = limit.read.source
                let (dimension, filter, from) = Self.window(step, last: last, at: now)
                var filters = [GraphQL.range(filter, from: from, to: now)]
                if let narrowed = focus.filter(for: source.focus) { filters.append(narrowed) }
                fields.append("\(alias): \(source.dataset)(limit: \(Self.groups), filter: { \(filters.joined(separator: ", ")) }, orderBy: [\(dimension)_ASC]) { dimensions { \(dimension) } \(GraphQL.selection(source.field)) }")
            case .top(let source, let dimension, let count):
                let filters = Self.filters(source, focus: focus, at: now)
                fields.append("\(alias): \(source.dataset)(limit: \(count), filter: { \(filters) }, orderBy: [\(GraphQL.orderKey(source.measure))_DESC]) { dimensions { \(dimension) } \(GraphQL.selection(source.measure)) }")
            case .split(let source, let dimension):
                let filters = Self.filters(source, focus: focus, at: now)
                if source.countsRows {
                    fields.append("\(alias): \(source.dataset)(limit: \(Self.groups), filter: { \(filters) }) { \(dimension) }")
                } else {
                    fields.append("\(alias): \(source.dataset)(limit: \(Self.groups), filter: { \(filters) }) { dimensions { \(dimension) } \(GraphQL.selection(source.measure)) }")
                }
            }
        }
        return PlannedBreakdowns(query: query(fields), service: service)
    }

    /// The last 24 hours of a list, filtered for the focus.
    static func filters(_ source: BreakdownDefinition.Source, focus: Focus, at now: Date) -> String {
        var filters = [GraphQL.range(source.time, from: now.addingTimeInterval(-86_400), to: now)]
        if let narrowed = focus.filter(for: source.focus) { filters.append(narrowed) }
        return filters.joined(separator: ", ")
    }

    /// The dimension, filter and start of a series of `last` steps ending now.
    static func window(_ step: BreakdownDefinition.Step, last: Int, at now: Date) -> (String, TimeFilter, Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        switch step {
        case .hour:
            let hour = calendar.dateInterval(of: .hour, for: now)!.start
            return ("datetimeHour", .datetimeHour, hour.addingTimeInterval(-3600 * Double(last - 1)))
        case .day:
            let day = calendar.startOfDay(for: now)
            return ("date", .date, calendar.date(byAdding: .day, value: -(last - 1), to: day)!)
        }
    }

    func query(_ fields: [String]) -> AnalyticsQuery {
        AnalyticsQuery(text: """
        { viewer { accounts(filter: { accountTag: \(GraphQL.string(account)) }) {
        \(fields.joined(separator: "\n"))
        } } }
        """)
    }
}

/// A limits query and how to read its answer.
public struct PlannedRead: Sendable {
    public let query: AnalyticsQuery
    let reads: [LimitRead]
    let readAt: Date

    /// Each limit's usage. A limit whose part of the answer is missing (refused, or an error
    /// on that dataset) is left out; one with no rows yet counts zero.
    public func usages(from answer: AnalyticsAnswer) throws(AnalyticsError) -> [LimitID: Usage] {
        let account = try GraphQL.account(in: answer)
        var usages: [LimitID: Usage] = [:]
        for (index, read) in reads.enumerated() {
            guard let groups = account["l\(index)"] as? [[String: Any]] else { continue }
            let source = read.definition.read.source
            let values = groups.compactMap { GraphQL.number(at: source.field, in: $0) }
            let value: Double = switch read.definition.read {
            case .sum: values.reduce(0, +)
            case .max, .quantile: values.max() ?? 0
            }
            var failures: Int?
            if case .quantile(let source) = read.definition.read, let rule = source.failures,
               let failed = account["l\(index)_failures"] as? [[String: Any]] {
                failures = Int(failed.compactMap { GraphQL.number(at: rule.measure, in: $0) }.reduce(0, +))
            }
            usages[read.definition.id] = Usage(
                used: Quantity(value * (source.scale ?? 1), read.definition.unit),
                period: read.period,
                readAt: readAt,
                failures: failures
            )
        }
        return usages
    }
}

/// A service tab's query and how to read its answer.
public struct PlannedBreakdowns: Sendable {
    public let query: AnalyticsQuery
    let service: ServiceDefinition

    public func breakdowns(from answer: AnalyticsAnswer) throws(AnalyticsError) -> [Breakdown] {
        let account = try GraphQL.account(in: answer)
        var result: [Breakdown] = []
        for (index, breakdown) in service.breakdowns.enumerated() {
            let groups = account["b\(index)"] as? [[String: Any]] ?? []
            switch breakdown.kind {
            case .series(let limitID, let step, _):
                guard let source = service.limits.first(where: { $0.id == limitID })?.read.source else { continue }
                let dimension = step == .hour ? "datetimeHour" : "date"
                let bars = groups.compactMap { group -> Bar? in
                    guard let stamp = GraphQL.text(at: "dimensions.\(dimension)", in: group),
                          let at = Self.date(stamp), let value = GraphQL.number(at: source.field, in: group) else { return nil }
                    return Bar(at: at, value: value * (source.scale ?? 1))
                }
                result.append(Breakdown(title: breakdown.title, content: .bars(bars.sorted { $0.at < $1.at })))
            case .top(let source, let dimension, _):
                let rows = groups.compactMap { group -> Row? in
                    guard let label = GraphQL.text(at: "dimensions.\(dimension)", in: group),
                          let value = GraphQL.number(at: source.measure, in: group) else { return nil }
                    return Row(label: label, value: value)
                }
                result.append(Breakdown(title: breakdown.title, content: .rows(rows.sorted { $0.value > $1.value })))
            case .split(let source, let dimension):
                var totals: [String: Double] = [:]
                for group in groups {
                    let label = GraphQL.text(at: source.countsRows ? dimension : "dimensions.\(dimension)", in: group) ?? "—"
                    totals[label, default: 0] += source.countsRows ? 1 : (GraphQL.number(at: source.measure, in: group) ?? 0)
                }
                let rows = totals.map { Row(label: $0.key, value: $0.value) }.sorted { ($0.value, $1.label) > ($1.value, $0.label) }
                result.append(Breakdown(title: breakdown.title, content: .rows(rows)))
            }
        }
        return result
    }

    static func date(_ stamp: String) -> Date? {
        if let time = ISO8601DateFormatter().date(from: stamp) { return time }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: stamp)
    }
}
