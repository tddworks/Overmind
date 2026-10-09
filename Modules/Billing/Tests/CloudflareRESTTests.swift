import Foundation
import Testing
import Measures
@testable import Billing

/// Cloudflare's REST answers, as recorded on 2026-10-09 with ids, names and emails replaced.
@Suite
struct CloudflareRESTTests {
    @Test func `should list the accounts a token can read`() throws {
        let json = #"{"success":true,"errors":[],"result":[{"id":"acc1","name":"Acme's Account","type":"standard"}]}"#
        #expect(try CloudflareREST.accounts(from: Data(json.utf8)) == [AccountSummary(id: "acc1", name: "Acme's Account")])
    }

    @Test func `should read each subscription's rate plan and renewal day`() throws {
        let json = #"{"success":true,"errors":[],"result":[{"id":"s1","rate_plan":{"id":"r2_paid","public_name":"R2 Paid"},"current_period_end":"2026-11-03T00:00:00Z","state":"Paid"},{"id":"s2","rate_plan":{"id":"workers_paid"}}]}"#
        let subscriptions = try CloudflareREST.subscriptions(from: Data(json.utf8))
        #expect(subscriptions.map(\.ratePlan) == ["r2_paid", "workers_paid"])
        #expect(subscriptions[0].renewsOn == .utc("2026-11-03T00:00:00"))
        #expect(subscriptions[1].renewsOn == nil)
    }

    @Test func `should read past invoices`() throws {
        let json = #"{"success":true,"errors":[],"result":[{"id":"in_1","amount":5.12,"currency":"USD","occurred_at":"2026-09-03T00:00:00Z","status":"paid"}]}"#
        #expect(try CloudflareREST.invoices(from: Data(json.utf8))
                == [Invoice(id: "in_1", amount: Money(Decimal(string: "5.12")!, "USD"), at: .utc("2026-09-03T00:00:00"), status: "paid")])
    }

    @Test func `should list a Worker's deployments, newest first`() throws {
        let json = #"{"success":true,"errors":[],"result":{"deployments":[{"id":"aaaa1111-0000","created_on":"2026-10-07T10:00:00.000000Z"},{"id":"d605dc93-0000","created_on":"2026-10-08T09:30:00.123456Z"}]}}"#
        let deployments = try CloudflareREST.deployments(from: Data(json.utf8))
        #expect(deployments.map(\.id) == ["d605dc93-0000", "aaaa1111-0000"])
        #expect(deployments[0].short == "d605dc93")
    }

    @Test func `should list the account's Workers by name`() throws {
        let json = #"{"success":true,"errors":[],"result":[{"id":"leaderboard"},{"id":"api"}]}"#
        #expect(try CloudflareREST.scripts(from: Data(json.utf8)) == ["api", "leaderboard"])
    }
}
