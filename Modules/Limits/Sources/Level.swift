import Measures

/// *OK · WATCH · ACT NOW* (CANONICAL law 2).
public enum Level: Sendable, Equatable, Comparable {
    case ok, watch, actNow

    public init(_ percent: Percent) {
        switch percent.value {
        case ..<50: self = .ok
        case ..<90: self = .watch
        default: self = .actNow
        }
    }
}
