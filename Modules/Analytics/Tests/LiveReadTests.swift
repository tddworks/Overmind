import Foundation
import Testing
import Measures
import Services
@testable import Analytics

/// Runs the real queries against Cloudflare, only when `OVERMIND_LIVE_TOKEN` and
/// `OVERMIND_LIVE_ACCOUNT` are set. Prints numbers, never the token or the account.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["OVERMIND_LIVE_TOKEN"] != nil))
struct LiveReadTests {
    let token = ProcessInfo.processInfo.environment["OVERMIND_LIVE_TOKEN"] ?? ""
    let account = ProcessInfo.processInfo.environment["OVERMIND_LIVE_ACCOUNT"] ?? ""

    @Test func `should read every built-in limit from a real account`() async throws {
        let api = Analytics.make(bearer: { [token] in token })
        let now = Date()
        let reads = try ServiceCatalog.builtIns().flatMap(\.limits).map { LimitRead($0, period: .day(containing: now)) }
        let planned = ReadPlan(account: account).limits(reads, at: now)

        let usages = try planned.usages(from: try await api.read(planned.query))

        for read in reads { print("LIVE", read.definition.id, usages[read.definition.id].map { "\($0.used.value) failures=\($0.failures ?? -1)" } ?? "unread") }
        #expect(usages.count == reads.count)
    }

    @Test func `should read every built-in breakdown from a real account`() async throws {
        let api = Analytics.make(bearer: { [token] in token })
        for service in try ServiceCatalog.builtIns() {
            let planned = ReadPlan(account: account).breakdowns(service, focus: .everything, at: Date())
            let answer = try await api.read(planned.query)
            if let text = String(data: answer.data, encoding: .utf8), text.contains("\"errors\":[") { print("LIVE errors", service.id, text.suffix(400)) }
            for breakdown in try planned.breakdowns(from: answer) {
                switch breakdown.content {
                case .bars(let bars): print("LIVE", breakdown.title, bars.count, "bars, last", bars.last?.value ?? 0)
                case .rows(let rows): print("LIVE", breakdown.title, rows.prefix(4).map { "\($0.label.prefix(30))=\($0.value)" })
                }
            }
        }
    }
}
