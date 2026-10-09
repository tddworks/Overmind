/// Which Worker (or database) a tab's charts describe: *leaderboard ▾ · All workers*. It narrows
/// breakdowns only; a limit always counts the whole account (CANONICAL law 1).
public struct Focus: Sendable, Equatable, Hashable, Codable {
    /// The dimension it narrows by, `scriptName`; nil for everything.
    public let dimension: String?
    public let value: String?

    public init(dimension: String, value: String) {
        self.dimension = dimension
        self.value = value
    }

    private init() {
        dimension = nil
        value = nil
    }

    public static let everything = Focus()

    /// The filter it adds to a source that can be narrowed by `focus`.
    func filter(for focus: String?) -> String? {
        guard let dimension, let value, dimension == focus else { return nil }
        return "\(dimension): \(GraphQL.string(value))"
    }
}
