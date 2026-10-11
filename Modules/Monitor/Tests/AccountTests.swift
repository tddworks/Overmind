import Foundation
import Testing
import Measures
import Limits
import Analytics
import Billing
import Services
@testable import Monitor

@MainActor
@Suite
struct ConnectTests {
    @Test func `should connect and read today's limits when the token answers for one account`() async throws {
        let world = World()
        world.cloudflare.numbers = ["rowsRead": 912_000]
        let account = try world.account()

        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))

        #expect(account.phase == .connected(AccountSummary(id: "acc1", name: "Acme")))
        #expect(world.vault.token == "tok")
        #expect(account.limit("d1.rowsRead")?.percent(at: .utc("2026-10-09T14:21:00"))?.rounded == 18)
    }

    @Test func `should ask which account to watch when the token answers for two`() async throws {
        let world = World()
        world.cloudflare.accountList = [AccountSummary(id: "a", name: "Acme"), AccountSummary(id: "b", name: "Personal")]
        let account = try world.account()

        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))

        #expect(account.phase == .choosing(world.cloudflare.accountList))
    }

    @Test func `should say Cloudflare refused and keep no token when the token is wrong`() async throws {
        let world = World()
        world.cloudflare.refuses = true
        let account = try world.account()

        await account.connect(token: "bad", at: .utc("2026-10-09T14:20:00"))

        #expect(account.phase == .refused(.invalidToken))
        #expect(world.vault.token == nil)
    }

    @Test func `should say the token can't see an account, not that it is wrong, when Cloudflare forbids the account list`() async throws {
        let world = World()
        world.cloudflare.forbidsAccounts = true
        let account = try world.account()

        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))

        #expect(account.phase == .refused(.cannotSeeAccount))
        #expect(world.vault.token == nil)
    }

    @Test func `should say the token can't read Account Analytics when Cloudflare forbids the usage query`() async throws {
        let world = World()
        world.cloudflare.forbidsAnalytics = true
        let account = try world.account()

        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))

        #expect(account.phase == .refused(.cannotReadAnalytics))
    }

    @Test func `should blame the Keychain, not Cloudflare, when the saved token can't be read back`() async throws {
        let world = World()
        world.cloudflare.tokenUnavailable = true
        let account = try world.account()

        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))

        #expect(account.phase == .notConnected)
        #expect(account.lastProblem == "Couldn't read the token back from the Keychain")
    }

    @Test func `should pick up where it left off after a relaunch`() async throws {
        let world = World()
        world.vault.token = "tok"
        world.settings.settings.account = AccountSummary(id: "acc1", name: "Acme")
        let account = try world.account()

        await account.start(at: .utc("2026-10-09T14:20:00"))

        #expect(account.phase == .connected(AccountSummary(id: "acc1", name: "Acme")))
        #expect(account.lastRead == .utc("2026-10-09T14:20:00"))
    }

    @Test func `should take the account to be on Free, and say invoices need Billing Read, when the token can't read billing`() async throws {
        let world = World()
        world.cloudflare.ratePlans = nil
        world.cloudflare.invoiceList = nil
        let account = try world.account()

        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))
        await account.openBill(at: .utc("2026-10-09T14:20:00"))

        #expect(account.plan.definition.id == "free")
        #expect(account.missing.contains(.billing))
    }

    @Test func `should forget the token and the account when the person disconnects`() async throws {
        let world = World()
        let account = try world.account()
        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))

        account.disconnect()

        #expect(account.phase == .notConnected)
        #expect(world.vault.token == nil)
        #expect(world.settings.settings.account == nil)
    }
}

@MainActor
@Suite
struct RefreshTests {
    func connected(_ world: World, at time: String = "2026-10-09T14:20:00") async throws -> Account {
        let account = try world.account()
        await account.connect(token: "tok", at: .utc(time))
        return account
    }

    @Test func `should show the limit closest to running out in the menu bar`() async throws {
        let world = World()
        world.cloudflare.numbers = ["rowsRead": 912_000, "requests": 9_814]
        let account = try await connected(world)

        #expect(account.closest(at: .utc("2026-10-09T14:21:00"))?.id == "d1.rowsRead")
        guard case .closest(let short, let percent, let level) = account.menuBar(at: .utc("2026-10-09T14:21:00")) else {
            Issue.record("the menu bar names no limit"); return
        }
        #expect(short == "D1")
        #expect(percent.rounded == 18)
        #expect(level == .ok)
    }

    @Test func `should never call CPU the closest limit, however high its p99`() async throws {
        let world = World()
        world.cloudflare.numbers = ["rowsRead": 912_000, "cpuTimeP99": 17_000]
        let account = try await connected(world)

        #expect(account.closest(at: .utc("2026-10-09T14:21:00"))?.id == "d1.rowsRead")
    }

    @Test func `should keep the last reading and say stale when Cloudflare can't be reached`() async throws {
        let world = World()
        world.cloudflare.numbers = ["rowsRead": 912_000]
        let account = try await connected(world)
        world.cloudflare.unreachable = true

        await account.refresh(at: .utc("2026-10-09T14:30:00"))

        #expect(account.freshness(at: .utc("2026-10-09T14:31:00")) == .stale)
        #expect(account.limit("d1.rowsRead")?.percent(at: .utc("2026-10-09T14:31:00"))?.rounded == 18)
    }

    @Test func `should say live while the last read is recent`() async throws {
        let account = try await connected(World())
        #expect(account.freshness(at: .utc("2026-10-09T14:25:00")) == .live)
    }

    @Test func `should say Cloudflare refused the token when it is revoked`() async throws {
        let world = World()
        let account = try await connected(world)
        world.cloudflare.refuses = true

        await account.refresh(at: .utc("2026-10-09T14:30:00"))

        #expect(account.phase == .refused(.invalidToken))
    }

    @Test func `should warn once when D1 rows read crosses 75%, and remember it after a relaunch`() async throws {
        let world = World()
        world.cloudflare.numbers = ["rowsRead": 3_800_000]
        let account = try await connected(world, at: "2026-10-09T21:14:00")
        await account.refresh(at: .utc("2026-10-09T21:20:00"))

        let relaunched = try world.account()
        await relaunched.start(at: .utc("2026-10-09T21:25:00"))

        #expect(world.notifier.posted.map(\.title).filter { $0.hasPrefix("D1 rows read") } == ["D1 rows read at 76%"])
    }

    @Test func `should show only the limits the account's plan counts`() async throws {
        let account = try await connected(World())
        #expect(account.limits.map(\.id) == ["workers.requests", "workers.cpu", "d1.rowsRead", "d1.rowsWritten", "d1.storage"])
    }

    @Test func `should count limits across every Worker even when one is in focus`() async throws {
        let world = World()
        let account = try await connected(world)
        account.focus = Focus(dimension: "scriptName", value: "leaderboard")

        await account.refresh(at: .utc("2026-10-09T14:30:00"))

        #expect(world.cloudflare.queries.last?.contains("scriptName") == false)
    }
}

@MainActor
@Suite
struct TabTests {
    @Test func `should read a service's charts for the focused Worker, with its deployments`() async throws {
        let world = World()
        let account = try world.account()
        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))
        account.focus = Focus(dimension: "scriptName", value: "leaderboard")

        await account.open("workers", at: .utc("2026-10-09T14:21:00"))

        #expect(account.breakdowns["workers"]?.map(\.title) == ["Requests · per hour today", "Invocations by outcome", "Cron runs"])
        #expect(account.deployments.map(\.short) == ["d605dc93"])
        #expect(world.cloudflare.queries.last?.contains(#"scriptName: "leaderboard""#) == true)
    }

    @Test func `should offer the account's Workers to focus on`() async throws {
        let world = World()
        let account = try world.account()
        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))
        #expect(account.workers == ["api", "leaderboard"])
    }

    @Test func `should quote Workers Paid for a Free account from this month's pace`() async throws {
        let world = World()
        world.cloudflare.numbers = ["rowsRead": 30_000_000]
        let account = try world.account()
        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))

        await account.openBill(at: .utc("2026-10-09T14:20:00"))

        #expect(account.bill?.estimate == Money(0, "USD"))
        #expect(account.quotes.map(\.plan.name) == ["Workers Paid"])
        #expect(account.quotes.first?.cost == Money(5, "USD"))
    }
}

@MainActor
@Suite
struct IntervalTests {
    @Test func `should read every 15 minutes when the person chooses it, and call a read stale only after 30`() async throws {
        let world = World()
        let account = try world.account()
        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))

        account.setInterval(minutes: 15)

        #expect(account.interval == 15 * 60)
        #expect(account.freshness(at: .utc("2026-10-09T14:45:00")) == .live)
        #expect(account.freshness(at: .utc("2026-10-09T14:51:00")) == .stale)
    }

    @Test func `should keep the read interval it has when asked for one it doesn't offer`() throws {
        let account = try World().account()
        account.setInterval(minutes: 7)
        #expect(account.interval == 5 * 60)
    }

    @Test func `should remember the read interval after a relaunch`() throws {
        let world = World()
        try world.account().setInterval(minutes: 30)
        #expect(try world.account().interval == 30 * 60)
    }
}

@MainActor
@Suite
struct UpgradeTests {
    @Test func `should pick up an upgrade made on Cloudflare when the Bill tab opens, without a restart`() async throws {
        let world = World()
        let account = try world.account()
        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))
        world.cloudflare.ratePlans = ["r2_paid", "workers_paid"]

        await account.openBill(at: .utc("2026-10-09T15:00:00"))

        #expect(account.plan.definition.name == "Workers Paid")
        #expect(account.limit("d1.rowsRead")?.allowance == .perMonth(Quantity(25e9, .rows)))
        #expect(account.quotes.map(\.plan.name) == ["Free"])
    }

    @Test func `should re-read the plan once a day while refreshing, and not on every read`() async throws {
        let world = World()
        let account = try world.account()
        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))
        let afterConnect = world.cloudflare.subscriptionReads

        await account.refresh(at: .utc("2026-10-09T14:25:00"))
        #expect(world.cloudflare.subscriptionReads == afterConnect)

        await account.refresh(at: .utc("2026-10-10T14:21:00"))
        #expect(world.cloudflare.subscriptionReads == afterConnect + 1)
    }

    @Test func `should say Free stopped D1 reads on the days they ran out this month`() async throws {
        let world = World()
        world.cloudflare.daily = ["rowsRead": ["2026-10-06": 2e6, "2026-10-07": 5e6, "2026-10-08": 5.2e6]]
        let account = try world.account()
        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))

        await account.openBill(at: .utc("2026-10-09T14:20:00"))

        #expect(account.bill?.verdict == .stopped(days: [Date.utc("2026-10-07T00:00:00"), Date.utc("2026-10-08T00:00:00")],
                                                  limits: ["d1.rowsRead"]))
    }

    @Test func `should show where Workers Paid's price would come from, and link to its page for this account`() async throws {
        let world = World()
        world.cloudflare.numbers = ["rowsRead": 30_000_000]
        let account = try world.account()
        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))

        await account.openBill(at: .utc("2026-10-09T14:20:00"))

        let paid = try #require(account.quotes.first)
        #expect(paid.lines.contains { $0.limit == "d1.rowsRead" })
        #expect(paid.upgradeURL?.absoluteString == "https://dash.cloudflare.com/acc1/workers/plans")
    }
}

/// Settings → Watching (law 21): only a watched service is read.
@MainActor
@Suite
struct WatchingTests {
    /// A service that ships off, as each new one does.
    static let later = try! ServiceDefinition(json: Data("""
    { "id": "later", "name": "Later", "order": 9, "look": { "glyph": "K", "color": "sky" },
      "limits": [ { "id": "later.calls", "name": "Later calls", "short": "Later", "unit": "count",
                    "read": { "sum": { "dataset": "laterGroups", "field": "sum.calls", "time": "date" } } } ],
      "breakdowns": [] }
    """.utf8))

    @Test func `should watch Workers and D1 for someone who never chose, and say the bill counts only them`() throws {
        let account = try World().account()

        #expect(account.watching.map(\.id) == ["workers", "d1"])
        #expect(account.estimateCovers == .only(["Worker", "D1"]))
    }

    @Test func `should leave a new service off until the person turns it on`() throws {
        let account = try World().account(adding: [Self.later])

        #expect(account.watching.map(\.id) == ["workers", "d1"])
        #expect(account.isWatching("later") == false)
        #expect(account.isWatching("kv") == false)
    }

    @Test func `should never read D1, warn about it or count it as closest once the person stops watching it`() async throws {
        let world = World()
        world.cloudflare.numbers = ["rowsRead": 4_900_000, "requests": 9_814]
        let account = try world.account()
        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))

        account.unwatch("d1")
        await account.refresh(at: .utc("2026-10-09T14:30:00"))

        #expect(account.limit("d1.rowsRead") == nil)
        #expect(world.cloudflare.queries.last?.contains("d1AnalyticsAdaptiveGroups") == false)
        #expect(account.closest(at: .utc("2026-10-09T14:31:00"))?.id == "workers.requests")
        #expect(account.estimateCovers == .only(["Worker"]))
    }

    @Test func `should leave D1 out of the bill when D1 isn't watched`() async throws {
        let world = World()
        let account = try world.account()
        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))
        account.unwatch("d1")
        let before = world.cloudflare.queries.count

        await account.openBill(at: .utc("2026-10-09T14:20:00"))

        #expect(world.cloudflare.queries.dropFirst(before).contains { $0.contains("d1AnalyticsAdaptiveGroups") || $0.contains("d1StorageAdaptiveGroups") } == false)
        #expect(account.quotes.first?.lines.map(\.limit).contains("d1.rowsRead") == false)
    }

    @Test func `should read a service at once when the person watches it again`() async throws {
        let world = World()
        world.cloudflare.numbers = ["rowsRead": 912_000]
        let account = try world.account()
        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))
        account.unwatch("d1")

        await account.watch("d1", at: .utc("2026-10-09T14:30:00"))

        #expect(account.limit("d1.rowsRead")?.percent(at: .utc("2026-10-09T14:31:00"))?.rounded == 18)
        #expect(account.estimateCovers == .only(["Worker", "D1"]))
    }

    @Test func `should keep watching the last service when the person tries to turn it off`() throws {
        let account = try World().account()

        account.unwatch("d1")
        account.unwatch("workers")

        #expect(account.watching.map(\.id) == ["workers"])
        #expect(account.canUnwatch("workers") == false)
    }

    @Test func `should remember what the person watches after a relaunch`() throws {
        let world = World()
        try world.account(adding: [Self.later]).unwatch("d1")
        let relaunched = try world.account(adding: [Self.later])

        #expect(relaunched.watching.map(\.id) == ["workers"])
    }

    @Test func `should ignore a service the catalog doesn't have`() async throws {
        let account = try World().account()

        await account.watch("nonesuch", at: .utc("2026-10-09T14:20:00"))

        #expect(account.watching.map(\.id) == ["workers", "d1"])
    }
}

/// The menu bar's states and the *icon only* choice (law 22).
@MainActor
@Suite
struct MenuBarTests {
    @Test func `should show only the cloud before the first read`() throws {
        let account = try World().account()
        #expect(account.menuBar(at: .utc("2026-10-09T14:21:00")) == .notReadYet)
    }

    @Test func `should show only the cloud and the act-now mark when the person chooses icon only`() async throws {
        let world = World()
        world.cloudflare.numbers = ["rowsRead": 4_600_000]
        let account = try world.account()
        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))

        account.setMenuBar(.iconOnly)

        #expect(account.menuBar(at: .utc("2026-10-09T14:21:00")) == .iconOnly(.actNow))
    }

    @Test func `should name the closest limit again when the person goes back to it`() async throws {
        let world = World()
        world.cloudflare.numbers = ["rowsRead": 912_000]
        let account = try world.account()
        await account.connect(token: "tok", at: .utc("2026-10-09T14:20:00"))
        account.setMenuBar(.iconOnly)

        account.setMenuBar(.closestLimit)

        guard case .closest(let short, _, _) = account.menuBar(at: .utc("2026-10-09T14:21:00")) else {
            Issue.record("the menu bar names no limit"); return
        }
        #expect(short == "D1")
    }

    @Test func `should remember icon only after a relaunch`() throws {
        let world = World()
        try world.account().setMenuBar(.iconOnly)
        #expect(try world.account().menuBarShows == .iconOnly)
    }
}
