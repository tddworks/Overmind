import Foundation
import Measures
import Plans
import Services

/// One thing counted against the plan: a card in *Every limit today*.
public struct Limit: Sendable, Equatable, Identifiable {
    public let definition: LimitDefinition
    public let allowance: Allowance
    public private(set) var usage: Usage?

    /// A pace needs this much of the period behind it; before that it's *too early to tell*.
    static let paceNeedsAtLeast: TimeInterval = 3600

    public init(_ definition: LimitDefinition, allowance: Allowance) {
        self.definition = definition
        self.allowance = allowance
    }

    public var id: LimitID { definition.id }

    /// The refresh tells it what Cloudflare said; it keeps the reading only if it is newer and
    /// not from an earlier period (law 7).
    public mutating func record(_ reading: Usage) {
        guard usage.map({ $0.isSuperseded(by: reading) }) ?? true else { return }
        usage = reading
    }

    /// The reading that describes `now`'s period; nil before the first read of it.
    public func current(at now: Date) -> Usage? {
        guard let usage, usage.isCurrent(at: now) else { return nil }
        return usage
    }

    /// How much of the allowance is used (law 2); nil with no current reading.
    public func percent(at now: Date) -> Percent? {
        guard let fraction = current(at: now)?.used.fraction(of: allowance.amount) else { return nil }
        return Percent(fraction: fraction)
    }

    public func level(at now: Date) -> Level? {
        percent(at: now).map(Level.init)
    }

    /// Where the rate ends the period (law 6): nil in the first hour, and for allowances that
    /// don't run down over a period.
    public func pace(at now: Date) -> Pace? {
        guard allowance.hasPace, let usage = current(at: now), let period = usage.period,
              let fraction = usage.used.fraction(of: allowance.amount) else { return nil }
        let elapsed = usage.readAt.timeIntervalSince(period.start)
        guard elapsed >= Self.paceNeedsAtLeast else { return nil }
        let rate = fraction * 100 / elapsed
        return Pace(atPeriodEnd: Percent(rate * period.length), start: period.start, end: period.end, rate: rate)
    }
}
