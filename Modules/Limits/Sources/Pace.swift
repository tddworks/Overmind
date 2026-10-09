import Foundation
import Measures

/// Where the current rate ends the period: *on pace for 31% by midnight* (CANONICAL law 6).
public struct Pace: Sendable, Equatable {
    /// The percent the period ends at if use goes on at this rate.
    public let atPeriodEnd: Percent
    let start: Date
    let end: Date
    /// Percent per second since the period began.
    let rate: Double

    /// When this rate reaches `percent`; nil if not before the period ends.
    public func reaches(_ percent: Percent) -> Date? {
        guard rate > 0 else { return nil }
        let at = start.addingTimeInterval((percent.value / rate).rounded())
        return at < end ? at : nil
    }
}
