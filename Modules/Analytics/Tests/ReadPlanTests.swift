import Foundation
import Testing
import Measures
import Services
import Limits
@testable import Analytics

@Suite
struct ReadPlanTests {
    let plan = ReadPlan(account: Fixture.account)

    func reads() throws -> [LimitRead] {
        [
            LimitRead(try Fixture.limit("d1", "d1.rowsRead"), period: Fixture.today),
            LimitRead(try Fixture.limit("workers", "workers.cpu"), period: Fixture.today),
            LimitRead(try Fixture.limit("d1", "d1.storage"), period: nil),
        ]
    }

    @Test func `should ask Cloudflare for every limit in one request`() throws {
        let query = plan.limits(try reads(), at: Fixture.now).query.text

        #expect(query.contains("l0: d1AnalyticsAdaptiveGroups"))
        #expect(query.contains("l1: workersInvocationsAdaptive"))
        #expect(query.contains("l2: d1StorageAdaptiveGroups"))
        #expect(query.components(separatedBy: "viewer").count == 2)
    }

    @Test func `should count only today's use for a daily limit`() throws {
        let query = plan.limits(try reads(), at: Fixture.now).query.text

        #expect(query.contains(#"date_geq: "2026-10-09", date_leq: "2026-10-09""#))
        #expect(query.contains(#"datetime_geq: "2026-10-09T00:00:00Z", datetime_leq: "2026-10-09T14:20:00Z""#))
    }

    @Test func `should count a limit across every Worker and database, never only the focused one`() throws {
        let query = plan.limits(try reads(), at: Fixture.now).query.text

        #expect(!query.contains("scriptName"))
        #expect(!query.contains("databaseId"))
    }

    @Test func `should read today's D1 rows read from Cloudflare's answer`() throws {
        let usages = try plan.limits(try reads(), at: Fixture.now).usages(from: AnalyticsAnswer(Fixture.limitsAnswer))

        let rowsRead = try #require(usages["d1.rowsRead"])
        #expect(rowsRead.used == Quantity(177_504, .rows))
        #expect(rowsRead.period == Fixture.today)
        #expect(rowsRead.readAt == Fixture.now)
    }

    @Test func `should show CPU in milliseconds and count the invocations that went past the allowance`() throws {
        let usages = try plan.limits(try reads(), at: Fixture.now).usages(from: AnalyticsAnswer(Fixture.limitsAnswer))

        let cpu = try #require(usages["workers.cpu"])
        #expect(cpu.used == Quantity(16.726, .milliseconds))
        #expect(cpu.failures == 3)
    }

    @Test func `should read storage as the size kept, with no period`() throws {
        let usages = try plan.limits(try reads(), at: Fixture.now).usages(from: AnalyticsAnswer(Fixture.limitsAnswer))

        #expect(usages["d1.storage"] == Usage(used: Quantity(512_000, .bytes), period: nil, readAt: Fixture.now))
    }

    @Test func `should count zero when Cloudflare has no rows for a limit yet today`() throws {
        let answer = Data(#"{"data":{"viewer":{"accounts":[{"l0":[],"l1":[],"l1_failures":[],"l2":[]}]}}}"#.utf8)
        let usages = try plan.limits(try reads(), at: Fixture.now).usages(from: AnalyticsAnswer(answer))

        #expect(usages["d1.rowsRead"]?.used == Quantity(0, .rows))
    }

    @Test func `should leave a limit unread when Cloudflare refused that part of the question`() throws {
        let answer = Data(#"{"data":{"viewer":{"accounts":[{"l0":[{"sum":{"rowsRead":5}}],"l1":null,"l2":null}]}},"errors":[{"message":"not authorized"}]}"#.utf8)
        let usages = try plan.limits(try reads(), at: Fixture.now).usages(from: AnalyticsAnswer(answer))

        #expect(usages["d1.rowsRead"]?.used == Quantity(5, .rows))
        #expect(usages["workers.cpu"] == nil)
    }

    @Test func `should say Cloudflare refused when the answer has no data at all`() throws {
        let answer = Data(#"{"data":null,"errors":[{"message":"authentication error"}]}"#.utf8)
        #expect(throws: AnalyticsError.rejected(["authentication error"])) {
            try plan.limits(try reads(), at: Fixture.now).usages(from: AnalyticsAnswer(answer))
        }
    }
}

@Suite
struct BreakdownPlanTests {
    let plan = ReadPlan(account: Fixture.account)

    @Test func `should narrow a tab's charts to the focused Worker`() throws {
        let workers = try ServiceCatalog.builtIn("workers")
        let query = plan.breakdowns(workers, focus: Focus(dimension: "scriptName", value: "leaderboard"), at: Fixture.now).query.text

        #expect(query.contains(#"scriptName: "leaderboard""#))
    }

    @Test func `should draw requests per hour as bars in time order`() throws {
        let workers = try ServiceCatalog.builtIn("workers")
        let planned = plan.breakdowns(workers, focus: .everything, at: Fixture.now)
        let answer = Data("""
        {"data":{"viewer":{"accounts":[{
          "b0":[{"dimensions":{"datetimeHour":"2026-10-09T13:00:00Z"},"sum":{"requests":640}},
                {"dimensions":{"datetimeHour":"2026-10-09T12:00:00Z"},"sum":{"requests":690}}],
          "b1":[], "b2":[]
        }]}}}
        """.utf8)

        let requests = try #require(try planned.breakdowns(from: AnalyticsAnswer(answer)).first)
        #expect(requests.title == "Requests · per hour today")
        #expect(requests.content == .bars([
            Bar(at: .utc("2026-10-09T12:00:00"), value: 690),
            Bar(at: .utc("2026-10-09T13:00:00"), value: 640),
        ]))
    }

    @Test func `should count cron runs by outcome`() throws {
        let workers = try ServiceCatalog.builtIn("workers")
        let planned = plan.breakdowns(workers, focus: .everything, at: Fixture.now)
        let answer = Data("""
        {"data":{"viewer":{"accounts":[{"b0":[],"b1":[],
          "b2":[{"status":"success"},{"status":"success"},{"status":"exceededCpu"}]
        }]}}}
        """.utf8)

        let cron = try #require(try planned.breakdowns(from: AnalyticsAnswer(answer)).last)
        #expect(cron.content == .rows([Row(label: "success", value: 2), Row(label: "exceededCpu", value: 1)]))
    }

    @Test func `should rank D1 queries by rows read, most first`() throws {
        let d1 = try ServiceCatalog.builtIn("d1")
        let planned = plan.breakdowns(d1, focus: .everything, at: Fixture.now)
        #expect(planned.query.text.contains("orderBy: [sum_rowsRead_DESC]"))

        let answer = Data("""
        {"data":{"viewer":{"accounts":[{"b0":[],"b1":[],
          "b2":[{"dimensions":{"query":"SELECT a"},"sum":{"rowsRead":396000}},
                {"dimensions":{"query":"SELECT b"},"sum":{"rowsRead":90000}}]
        }]}}}
        """.utf8)
        let top = try #require(try planned.breakdowns(from: AnalyticsAnswer(answer)).last)
        #expect(top.content == .rows([Row(label: "SELECT a", value: 396_000), Row(label: "SELECT b", value: 90_000)]))
    }
}
