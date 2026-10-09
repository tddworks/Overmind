import Foundation
import Measures

/// How much of a limit was used, in which period, read when. For a per-invocation allowance
/// `used` is the period's p99 and `failures` the invocations that went past it.
public struct Usage: Sendable, Equatable {
    public let used: Quantity
    /// Nil for what never resets (storage).
    public let period: Period?
    public let readAt: Date
    public let failures: Int?

    public init(used: Quantity, period: Period?, readAt: Date, failures: Int? = nil) {
        self.used = used
        self.period = period
        self.readAt = readAt
        self.failures = failures
    }

    /// Whether this reading still describes the period `now` is in (law 7).
    func isCurrent(at now: Date) -> Bool {
        period?.contains(now) ?? true
    }

    /// Whether `reading` should replace this one: newer, and not from an earlier period.
    func isSuperseded(by reading: Usage) -> Bool {
        guard reading.readAt > readAt else { return false }
        guard let mine = period, let theirs = reading.period else { return true }
        return theirs.start >= mine.start
    }
}
