import Testing
import Measures
@testable import Services

/// The built-in service files, read through the real JSON.
@Suite
struct BuiltInServicesTests {
    @Test func `should show Workers, then D1, KV, Queues, R2, Workers AI, Vectorize and Durable Objects`() throws {
        #expect(try ServiceCatalog.builtIns().map(\.id) == ["workers", "d1", "kv", "queues", "r2", "ai", "vectorize", "durable-objects"])
    }

    @Test func `should leave every service but Workers and D1 off until the person watches it`() throws {
        #expect(try ServiceCatalog.builtIns().filter { !$0.watchedByDefault }.map(\.id)
                == ["kv", "queues", "r2", "ai", "vectorize", "durable-objects"])
    }

    @Test func `should know Workers AI counts neurons across every model`() throws {
        let neurons = try #require(try ServiceCatalog.builtIn("ai").limits.first)
        #expect(neurons.id == "ai.neurons")
        #expect(neurons.unit == .neurons)
        #expect(neurons.read == .sum(Read.Source(dataset: "aiInferenceAdaptiveGroups", field: "sum.totalNeurons", time: .datetime)))
    }

    @Test func `should know Vectorize counts queried dimensions, and stored dimensions across every index`() throws {
        let vectorize = try ServiceCatalog.builtIn("vectorize")
        #expect(vectorize.limits.map(\.id) == ["vectorize.queried", "vectorize.stored"])
        #expect(vectorize.limits[1].read == .max(Read.Source(dataset: "vectorizeV2StorageAdaptiveGroups", field: "max.storedVectorDimensions",
                                                             time: .datetime, focus: "indexName")))
    }

    @Test func `should know Durable Objects counts requests, SQLite rows and storage`() throws {
        let objects = try ServiceCatalog.builtIn("durable-objects")
        #expect(objects.limits.map(\.id) == ["durable-objects.requests", "durable-objects.rowsRead",
                                             "durable-objects.rowsWritten", "durable-objects.storage"])
        #expect(objects.limits[1].read == .sum(Read.Source(dataset: "durableObjectsPeriodicGroups", field: "sum.rowsRead",
                                                           time: .datetime, focus: "namespaceId")))
    }

    @Test func `should know R2's Class B is reads like GetObject and HeadObject, and leave R2 off until watched`() throws {
        let r2 = try ServiceCatalog.builtIn("r2")

        let classB = try #require(r2.limits.first { $0.id == "r2.classB" })
        #expect(classB.read.source.dataset == "r2OperationsAdaptiveGroups")
        #expect(classB.read.source.where?.dimension == "actionType")
        #expect(classB.read.source.where?.in.contains("GetObject") == true)
        #expect(classB.read.source.where?.in.contains("PutObject") == false)
        #expect(r2.watchedByDefault == false)
    }

    @Test func `should know Queues counts billable operations across every queue, and leave Queues off until watched`() throws {
        let queues = try ServiceCatalog.builtIn("queues")

        let operations = try #require(queues.limits.first)
        #expect(operations.id == "queues.operations")
        #expect(operations.unit == .operations)
        #expect(operations.read == .sum(Read.Source(dataset: "queueMessageOperationsAdaptiveGroups", field: "sum.billableOperations",
                                                    time: .datetime, focus: "queueId")))
        #expect(queues.watchedByDefault == false)
    }

    @Test func `should know KV writes are KV's write operations`() throws {
        let kv = try ServiceCatalog.builtIn("kv")

        let writes = try #require(kv.limits.first { $0.id == "kv.writes" })
        #expect(writes.read == .sum(Read.Source(dataset: "kvOperationsAdaptiveGroups", field: "sum.requests", time: .date,
                                                where: Read.Where(dimension: "actionType", in: ["write"]))))
        #expect(kv.limits.map(\.id) == ["kv.reads", "kv.writes", "kv.deletes", "kv.lists", "kv.storage"])
        #expect(kv.watchedByDefault == false)
    }

    @Test func `should add up every KV namespace's size for storage, since the 1 GB covers them all`() throws {
        let storage = try #require(try ServiceCatalog.builtIn("kv").limits.first { $0.id == "kv.storage" })
        #expect(storage.read == .max(Read.Source(dataset: "kvStorageAdaptiveGroups", field: "max.byteCount",
                                                 time: .date, focus: "namespaceId")))
    }

    @Test func `should watch Workers and D1 for someone who never chose`() throws {
        #expect(try ServiceCatalog.builtIns().filter(\.watchedByDefault).map(\.id) == ["workers", "d1"])
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
