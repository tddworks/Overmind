/// How much of an allowance is used: *18%*.
public struct Percent: Sendable, Equatable, Hashable, Comparable {
    public let value: Double

    /// Kept to a millionth of a percent, so the same share always compares equal.
    public init(_ value: Double) { self.value = (value * 1e6).rounded() / 1e6 }
    public init(fraction: Double) { self.init(fraction * 100) }

    /// The whole number the screen prints.
    public var rounded: Int { Int(value.rounded()) }

    public static func < (lhs: Percent, rhs: Percent) -> Bool { lhs.value < rhs.value }
}
