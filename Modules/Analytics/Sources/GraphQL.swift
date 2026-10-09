import Foundation
import Measures
import Services

/// Writing GraphQL text and reading its JSON answer back. Kept to what `ReadPlan` needs.
enum GraphQL {
    static func string(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// `sum.rowsRead` → `sum { rowsRead }`; `count` → `count`.
    static func selection(_ path: String) -> String {
        let parts = path.split(separator: ".").map(String.init)
        return parts.dropLast().reversed().reduce(parts.last ?? path) { inner, outer in "\(outer) { \(inner) }" }
    }

    /// `sum.rowsRead` → `sum_rowsRead`, for `orderBy`.
    static func orderKey(_ path: String) -> String {
        path.replacingOccurrences(of: ".", with: "_")
    }

    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func time(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    /// The time filter over `[from, to]` in the form a dataset takes.
    static func range(_ filter: TimeFilter, from: Date, to: Date) -> String {
        switch filter {
        case .date: "date_geq: \(string(day(from))), date_leq: \(string(day(to)))"
        case .datetime: "datetime_geq: \(string(time(from))), datetime_leq: \(string(time(to)))"
        case .datetimeHour: "datetimeHour_geq: \(string(time(from))), datetimeHour_leq: \(string(time(to)))"
        }
    }

    /// The account's object in the answer, or the errors when there is none.
    static func account(in answer: AnalyticsAnswer) throws(AnalyticsError) -> [String: Any] {
        let json = (try? JSONSerialization.jsonObject(with: answer.data)) as? [String: Any]
        let errors = (json?["errors"] as? [[String: Any]])?.compactMap { $0["message"] as? String } ?? []
        guard let data = json?["data"] as? [String: Any],
              let viewer = data["viewer"] as? [String: Any],
              let account = (viewer["accounts"] as? [[String: Any]])?.first else {
            throw .rejected(errors.isEmpty ? ["no data in Cloudflare's answer"] : errors)
        }
        return account
    }

    /// The number at `path` in one group; nil when it isn't there.
    static func number(at path: String, in group: [String: Any]) -> Double? {
        var node: Any? = group
        for key in path.split(separator: ".") { node = (node as? [String: Any])?[String(key)] }
        return (node as? NSNumber)?.doubleValue
    }

    static func text(at path: String, in group: [String: Any]) -> String? {
        var node: Any? = group
        for key in path.split(separator: ".") { node = (node as? [String: Any])?[String(key)] }
        return (node as? String) ?? (node as? NSNumber)?.stringValue
    }
}
