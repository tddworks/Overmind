import Foundation
import Measures

/// A Cloudflare product, as data: *D1*, *Worker*. Built-ins ship in this module's bundle.
public struct ServiceDefinition: Sendable, Equatable, Decodable, Identifiable {
    public let id: String
    public let name: String
    /// Where the service sits among the tabs; lower first.
    public let order: Int
    public let look: Look
    public let limits: [LimitDefinition]
    public let breakdowns: [BreakdownDefinition]

    public struct Look: Sendable, Equatable, Codable {
        public let glyph: String
        public let color: String
    }

    public init(json: Data) throws(DefinitionError) {
        let definition: ServiceDefinition
        do {
            definition = try JSONDecoder().decode(ServiceDefinition.self, from: json)
        } catch let error as DefinitionError {
            throw error
        } catch {
            throw .unreadable("\(error)")
        }
        try definition.validate()
        self = definition
    }

    /// A chart may only draw a limit this service has.
    func validate() throws(DefinitionError) {
        let ids = Set(limits.map(\.id))
        for breakdown in breakdowns {
            if case .series(let limit, _, _) = breakdown.kind, !ids.contains(limit) {
                throw .unknownLimit(limit, in: id)
            }
        }
    }
}

/// One thing a service counts: *D1 rows read*. Its allowance comes from the plan.
public struct LimitDefinition: Sendable, Equatable, Codable, Identifiable {
    public let id: LimitID
    public let name: String
    /// The menu bar's word: *D1*.
    public let short: String
    public let unit: QuantityUnit
    public let read: Read

    public init(id: LimitID, name: String, short: String, unit: QuantityUnit, read: Read) {
        self.id = id
        self.name = name
        self.short = short
        self.unit = unit
        self.read = read
    }
}

public enum DefinitionError: Error, Equatable, Sendable {
    case notFound(String)
    case unreadable(String)
    case unknownCase(String)
    case unknownLimit(LimitID, in: String)
}
