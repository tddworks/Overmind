import Testing
import Measures
@testable import Services

/// The built-in service files, read through the real JSON.
@Suite
struct BuiltInServicesTests {
    @Test func `should show Workers before D1`() throws {
        #expect(try ServiceCatalog.builtIns().map(\.id) == ["workers", "d1"])
    }

    @Test func `should watch Workers and D1 for someone who never chose`() throws {
        #expect(try ServiceCatalog.builtIns().allSatisfy(\.watchedByDefault))
    }

    @Test func `should know D1 counts rows read from D1's analytics, narrowed to a database only on its tab`() throws {
        let d1 = try ServiceCatalog.builtIn("d1")

        let rowsRead = try #require(d1.limits.first { $0.id == "d1.rowsRead" })
        #expect(rowsRead.read == .sum(Read.Source(dataset: "d1AnalyticsAdaptiveGroups", field: "sum.rowsRead",
                                                  time: .date, focus: "databaseId")))
        #expect(rowsRead.short == "D1")
    }

    @Test func `should know D1 storage is the largest size seen in the period`() throws {
        let storage = try #require(try ServiceCatalog.builtIn("d1").limits.first { $0.id == "d1.storage" })
        #expect(storage.read == .max(Read.Source(dataset: "d1StorageAdaptiveGroups", field: "max.databaseSizeBytes",
                                                 time: .date, focus: "databaseId")))
        #expect(storage.unit == .bytes)
    }

    @Test func `should know Workers CPU is the p99 in microseconds, shown in milliseconds, failing past the allowance`() throws {
        let cpu = try #require(try ServiceCatalog.builtIn("workers").limits.first { $0.id == "workers.cpu" })
        guard case .quantile(let source) = cpu.read else { Issue.record("CPU is not a percentile"); return }
        #expect(source.field == "quantiles.cpuTimeP99")
        #expect(source.scale == 0.001)
        #expect(source.failures == Read.Failures(dimension: "status", equals: "exceededResources", measure: "sum.requests"))
    }

    @Test func `should draw the cron runs on the Workers tab`() throws {
        let workers = try ServiceCatalog.builtIn("workers")
        let cron = BreakdownDefinition.Source(dataset: "workersInvocationsScheduled", measure: "rows", time: .datetime, focus: "scriptName")
        #expect(workers.breakdowns.contains { $0.kind == .split(cron, dimension: "status") })
    }
}
