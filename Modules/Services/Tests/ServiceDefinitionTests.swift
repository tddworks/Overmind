import Foundation
import Testing
import Measures
@testable import Services

@Suite
struct ServiceDefinitionTests {
    static let acme = """
    {
      "id": "acme", "name": "Acme", "order": 1, "look": { "glyph": "A", "color": "sky" },
      "limits": [
        { "id": "acme.widgets", "name": "Widgets made", "short": "Widgets", "unit": "count",
          "read": { "sum": { "dataset": "acmeGroups", "field": "sum.widgets", "time": "date", "focus": "factoryId" } } },
        { "id": "acme.latency", "name": "Latency", "short": "Latency", "unit": "milliseconds",
          "read": { "quantile": { "dataset": "acmeGroups", "field": "quantiles.latencyP99", "time": "datetime",
                                  "scale": 0.001, "failures": { "dimension": "status", "equals": "tooSlow", "measure": "sum.requests" } } } }
      ],
      "breakdowns": [
        { "title": "Widgets · last 7 days", "series": { "limit": "acme.widgets", "by": "day", "last": 7 } },
        { "title": "Top factories", "top": { "dataset": "acmeGroups", "dimension": "factoryId",
                                            "measure": "sum.widgets", "count": 5, "time": "date" } }
      ]
    }
    """

    @Test func `should know what a service counts and where Cloudflare keeps the number`() throws {
        let acme = try ServiceDefinition(json: Data(Self.acme.utf8))

        let widgets = try #require(acme.limits.first)
        #expect(widgets.id == "acme.widgets")
        #expect(widgets.short == "Widgets")
        #expect(widgets.read == .sum(Read.Source(dataset: "acmeGroups", field: "sum.widgets", time: .date, focus: "factoryId")))
    }

    @Test func `should know a latency limit is a percentile counted in milliseconds from microseconds`() throws {
        let acme = try ServiceDefinition(json: Data(Self.acme.utf8))

        guard case .quantile(let source) = acme.limits[1].read else { Issue.record("not a percentile"); return }
        #expect(source.scale == 0.001)
        #expect(source.failures == Read.Failures(dimension: "status", equals: "tooSlow", measure: "sum.requests"))
    }

    @Test func `should know which charts a service's tab draws`() throws {
        let acme = try ServiceDefinition(json: Data(Self.acme.utf8))

        #expect(acme.breakdowns.map(\.title) == ["Widgets · last 7 days", "Top factories"])
        #expect(acme.breakdowns[0].kind == .series(limit: "acme.widgets", by: .day, last: 7))
    }

    @Test func `should refuse a limit that is read in a way Edge Meter doesn't know`() {
        let odd = Self.acme.replacingOccurrences(of: "\"sum\": { \"dataset\"", with: "\"median\": { \"dataset\"")
        #expect(throws: DefinitionError.self) { try ServiceDefinition(json: Data(odd.utf8)) }
    }

    @Test func `should refuse a chart about a limit the service doesn't have`() {
        let odd = Self.acme.replacingOccurrences(of: "\"limit\": \"acme.widgets\"", with: "\"limit\": \"acme.gadgets\"")
        #expect(throws: DefinitionError.self) { try ServiceDefinition(json: Data(odd.utf8)) }
    }
}
