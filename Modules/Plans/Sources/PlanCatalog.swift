import Foundation

/// Finds plan definitions. Built-ins ship in this module's bundle; no Swift lists one.
public enum PlanCatalog {
    public static func builtIn(_ id: String) throws(PlanError) -> PlanDefinition {
        guard let url = Bundle.module.url(forResource: id, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { throw .notFound(id) }
        return try PlanDefinition(json: data)
    }

    public static func builtIns() throws(PlanError) -> [PlanDefinition] {
        var plans: [PlanDefinition] = []
        for url in Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [] {
            guard let data = try? Data(contentsOf: url) else { throw .notFound(url.lastPathComponent) }
            plans.append(try PlanDefinition(json: data))
        }
        return plans.sorted { $0.id < $1.id }
    }

    /// The plan an account is on, from the `rate_plan` ids of its subscriptions: the first
    /// definition that matches one, else the one that matches nothing (Free).
    public static func plan(forRatePlans ratePlans: [String]) throws(PlanError) -> PlanDefinition {
        try plan(forRatePlans: ratePlans, among: builtIns())
    }

    public static func plan(forRatePlans ratePlans: [String], among plans: [PlanDefinition]) throws(PlanError) -> PlanDefinition {
        if let paid = plans.first(where: { !Set($0.matches).isDisjoint(with: ratePlans) }) { return paid }
        guard let free = plans.first(where: \.matches.isEmpty) else { throw .notFound("a plan that matches nothing") }
        return free
    }
}

extension Array where Element == PlanDefinition {
    /// Every built-in plan.
    public static func builtIns() throws(PlanError) -> [PlanDefinition] { try PlanCatalog.builtIns() }
}
