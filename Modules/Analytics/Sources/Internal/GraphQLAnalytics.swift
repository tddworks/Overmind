import Foundation
import Diagnostics

/// The `AnalyticsAPI` port over `POST https://api.cloudflare.com/client/v4/graphql`.
/// GraphQL's POST is a read. Never logs the token or the answer.
struct GraphQLAnalytics: AnalyticsAPI {
    let bearer: @Sendable () async throws -> String
    var endpoint = URL(string: "https://api.cloudflare.com/client/v4/graphql")!
    var session: URLSession = .shared

    func read(_ query: AnalyticsQuery) async throws -> AnalyticsAnswer {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(try await bearer())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query.text])
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AnalyticsError.unreachable(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            AppLog.analytics.error("GraphQL answered HTTP \(status, privacy: .public)")
            switch status {
            case 401: throw AnalyticsError.refused
            case 403: throw AnalyticsError.forbidden
            default: throw AnalyticsError.unreachable("HTTP \(status)")
            }
        }
        return AnalyticsAnswer(data)
    }
}
