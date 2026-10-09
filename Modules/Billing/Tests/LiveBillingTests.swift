import Foundation
import Testing
@testable import Billing

/// Runs against Cloudflare only when `EDGEMETER_LIVE_TOKEN` is set. Prints counts, never ids.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["EDGEMETER_LIVE_TOKEN"] != nil))
struct LiveBillingTests {
    let token = ProcessInfo.processInfo.environment["EDGEMETER_LIVE_TOKEN"] ?? ""

    @Test func `should read a real account's plan, Workers and deployments`() async throws {
        let api = Billing.make(bearer: { [token] in token })
        let account = try #require(try await api.accounts().first)
        let subscriptions = try await api.subscriptions(account: account.id)
        print("LIVE subscriptions", subscriptions.map(\.ratePlan), "renews", subscriptions.compactMap(\.renewsOn).count)
        let scripts = try await api.scripts(account: account.id)
        print("LIVE scripts", scripts.count)
        if let script = scripts.first {
            let deployments = try await api.deployments(account: account.id, script: script)
            print("LIVE deployments", deployments.count, "newest", deployments.first?.at as Any)
        }
        do { print("LIVE invoices", try await api.invoices(account: account.id).count) } catch { print("LIVE invoices", error) }
    }
}
