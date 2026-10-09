import Foundation
import Mockable

/// Analytics — every limit as one GraphQL read, and the answer back as `Usage` and
/// `Breakdown` (TARGET_ARCHITECTURE §3.2–3.3). The factory builds the port's implementation.
public enum Analytics {
    /// The port over Cloudflare's GraphQL API. `bearer` answers the token for each read.
    public static func make(bearer: @escaping @Sendable () async throws -> String) -> any AnalyticsAPI {
        GraphQLAnalytics(bearer: bearer)
    }
}

/// What lies outside: Cloudflare's GraphQL Analytics API. A read, never a write (law 16).
@Mockable
public protocol AnalyticsAPI: Sendable {
    func read(_ query: AnalyticsQuery) async throws -> AnalyticsAnswer
}

/// One GraphQL query.
public struct AnalyticsQuery: Sendable, Equatable {
    public let text: String

    public init(text: String) { self.text = text }
}

/// Cloudflare's answer, as it came.
public struct AnalyticsAnswer: Sendable, Equatable {
    public let data: Data

    public init(_ data: Data) { self.data = data }
}

public enum AnalyticsError: Error, Equatable, Sendable {
    /// Cloudflare refused the token itself (401/403).
    case refused
    /// The network or Cloudflare couldn't be reached.
    case unreachable(String)
    /// Cloudflare answered with errors and no data.
    case rejected([String])
}
