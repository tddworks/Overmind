import Foundation
import Testing
import Analytics
import Billing
@testable import Monitor

/// The whole flow against Cloudflare, only when `OVERMIND_LIVE_TOKEN` is set: connect, read,
/// open each tab, price the month. Keeps nothing; prints numbers, never ids.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["OVERMIND_LIVE_TOKEN"] != nil))
struct LiveAccountTests {
    @Test func `should connect, read and price a real account end to end`() async throws {
        let token = ProcessInfo.processInfo.environment["OVERMIND_LIVE_TOKEN"] ?? ""
        let vault = FakeVault()
        let bearer: @Sendable () async throws -> String = { token }
        let account = try Account(services: .builtIns(), plans: .builtIns(), analytics: Analytics.make(bearer: bearer),
                                  billing: Billing.make(bearer: bearer), vault: vault, settings: FakeSettings(), notifier: FakeNotifier())
        let now = Date()

        await account.connect(token: token, at: now)
        guard case .connected = account.phase else { Issue.record("not connected: \(account.phase)"); return }
        print("LIVE plan", account.plan.definition.name, "missing", account.missing, "workers", account.workers.count)
        for limit in account.limits {
            print("LIVE", limit.id, limit.current(at: now)?.used.short ?? "—", limit.percent(at: now).map { "\($0.rounded)%" } ?? "—",
                  limit.level(at: now).map { "\($0)" } ?? "—")
        }
        print("LIVE menu bar", account.menuBar(at: now), account.freshness(at: now))
        if let worker = account.workers.first(where: { $0.contains("leaderboard") }) ?? account.workers.first {
            account.focus = Focus(dimension: "scriptName", value: worker)
        }
        for service in account.services {
            await account.open(service.id, at: now)
            print("LIVE tab", service.id, account.breakdowns[service.id]?.map(\.title) ?? [], "pins", account.deployments.count)
        }
        await account.openBill(at: now)
        print("LIVE bill", account.bill.map { "\($0.estimate.amount) forecast \($0.forecast.amount)" } ?? "—",
              account.quotes.map { "\($0.plan.name) \($0.cost.amount)" })
        #expect(account.lastRead != nil)
    }
}
