import Foundation
import Mockable
import Measures
import Limits

/// *Warn me at 50% 75% 90% · pace · Notify* — and the once-only log of what was sent
/// (CANONICAL laws 9–10).
public struct Alerts: Sendable, Equatable {
    public var settings: AlertSettings
    public private(set) var sent: Set<Warning.Key>

    /// Warnings from periods older than this are forgotten.
    static let memory: TimeInterval = 40 * 86_400

    public init(settings: AlertSettings = .standard, sent: Set<Warning.Key> = []) {
        self.settings = settings
        self.sent = sent
    }

    /// The warnings that are new at `now`, marked as sent.
    public mutating func check(_ limits: [Limit], at now: Date) -> [Warning] {
        sent = sent.filter { now.timeIntervalSince($0.period) < Self.memory }
        guard settings.isOn else { return [] }
        return limits.compactMap { limit in failures(limit, at: now) }
            + limits.compactMap { limit in level(limit, at: now) }
            + limits.compactMap { limit in pace(limit, at: now) }
    }

    /// Cloudflare stopped invocations for a per-invocation allowance: once a period.
    mutating func failures(_ limit: Limit, at now: Date) -> Warning? {
        guard !limit.runsOut, let usage = limit.current(at: now), let failed = usage.failures, failed > 0 else { return nil }
        let key = Warning.Key(limit: limit.id, mark: .stopped, period: usage.period?.start ?? .distantPast)
        guard sent.insert(key).inserted else { return nil }
        return Warning(key: key,
                       title: "\(limit.definition.name): \(failed) invocation\(failed == 1 ? "" : "s") stopped",
                       body: "They went past the \(limit.allowance.amount.short) each one is allowed.")
    }

    /// A level crossed: one warning for the highest new one; every crossed level is marked.
    mutating func level(_ limit: Limit, at now: Date) -> Warning? {
        guard limit.runsOut, let usage = limit.current(at: now), let percent = limit.percent(at: now) else { return nil }
        let period = usage.period?.start ?? .distantPast
        let crossed = settings.levels.filter { percent.value >= Double($0) }
        let new = crossed.filter { !sent.contains(Warning.Key(limit: limit.id, mark: .level($0), period: period)) }
        guard let highest = new.max() else { return nil }
        for level in crossed { sent.insert(Warning.Key(limit: limit.id, mark: .level(level), period: period)) }
        var body = "\(usage.used.short) of \(limit.allowance.amount.short)"
        if let pace = limit.pace(at: now) { body += " · on pace for \(pace.atPeriodEnd.rounded)% by the reset" }
        return Warning(key: Warning.Key(limit: limit.id, mark: .level(highest), period: period),
                       title: "\(limit.definition.name) at \(percent.rounded)%", body: body)
    }

    /// The pace would cross 90% before the period ends, while it is still under (law 10).
    mutating func pace(_ limit: Limit, at now: Date) -> Warning? {
        guard settings.pace, let usage = limit.current(at: now), let percent = limit.percent(at: now), percent < Self.paceLine,
              let pace = limit.pace(at: now), let when = pace.reaches(Self.paceLine) else { return nil }
        let key = Warning.Key(limit: limit.id, mark: .pace, period: usage.period?.start ?? .distantPast)
        guard sent.insert(key).inserted else { return nil }
        return Warning(key: key,
                       title: "Pace: \(limit.definition.name) would cross 90% at \(Self.clock(when)) UTC",
                       body: "\(percent.rounded)% now · on pace for \(pace.atPeriodEnd.rounded)% by the reset")
    }

    static let paceLine = Percent(90)

    static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

public struct AlertSettings: Sendable, Equatable, Codable {
    public var levels: Set<Int>
    public var pace: Bool
    public var isOn: Bool

    public init(levels: Set<Int>, pace: Bool, isOn: Bool) {
        self.levels = levels
        self.pace = pace
        self.isOn = isOn
    }

    public static let standard = AlertSettings(levels: [50, 75, 90], pace: true, isOn: true)
    /// The levels the *Warn me at* chips offer.
    public static let offered = [50, 75, 90]
}

/// A notification Overmind sent.
public struct Warning: Sendable, Equatable {
    public let key: Key
    public let title: String
    public let body: String

    /// What makes a warning the same one: the limit, which mark, which period.
    public struct Key: Sendable, Hashable, Codable {
        public let limit: LimitID
        public let mark: Mark
        public let period: Date

        public init(limit: LimitID, mark: Mark, period: Date) {
            self.limit = limit
            self.mark = mark
            self.period = period
        }
    }

    public enum Mark: Sendable, Hashable, Codable {
        case level(Int)
        case pace
        case stopped
    }
}

/// What lies outside: the system's notifications.
@Mockable
public protocol Notifier: Sendable {
    func post(_ warning: Warning) async
}

extension Alerts {
    /// The notifier over the system's User Notifications.
    public static func makeNotifier() -> any Notifier { UserNotifier() }
}
