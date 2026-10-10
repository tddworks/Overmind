import Foundation
import Analytics
import Billing
import Alerts
import Monitor

/// Made-up data for screenshots and trying the app without an account (OVERMIND_DEMO=1).
/// Nothing here reaches Cloudflare, the Keychain or the settings file.
enum Demo {
    static let isOn = ProcessInfo.processInfo.environment["OVERMIND_DEMO"] == "1"

    /// The demo's fixed clock, so the screenshots match the mockup.
    static let now: Date? = isOn ? ISO8601DateFormatter().date(from: "2026-10-09T14:20:00Z") : nil

    @MainActor
    static func account() -> Account {
        let account = try! Account(services: .builtIns(), plans: .builtIns(), analytics: DemoCloudflare(), billing: DemoCloudflare(),
                                   vault: MemoryVault(token: "demo"),
                                   settings: MemorySettings(Settings(account: AccountSummary(id: "demo", name: "acme"),
                                                                     focus: Focus(dimension: "scriptName", value: "leaderboard"))),
                                   notifier: SilentNotifier())
        return account
    }
}

/// Answers any query `ReadPlan` writes with plausible numbers.
struct DemoCloudflare: AnalyticsAPI, BillingAPI {
    static let numbers: [String: Double] = [
        "rowsRead": 912_000, "rowsWritten": 12_400, "databaseSizeBytes": 41_000_000,
        "requests": 9_814, "cpuTimeP99": 7_800, "cpuTimeUs": 21_000_000,
    ]

    func read(_ query: AnalyticsQuery) async throws -> AnalyticsAnswer {
        var account: [String: Any] = [:]
        for line in query.text.split(separator: "\n") {
            guard let colon = line.firstIndex(of: ":"), let body = line.range(of: ") {") else { continue }
            let alias = String(line[..<colon])
            let tokens = line[body.upperBound...].split(whereSeparator: { " {}".contains($0) }).map(String.init)
            account[alias] = Self.groups(alias: alias, tokens: tokens)
        }
        let json: [String: Any] = ["data": ["viewer": ["accounts": [account]]]]
        return AnalyticsAnswer(try JSONSerialization.data(withJSONObject: json))
    }

    static func groups(alias: String, tokens: [String]) -> [[String: Any]] {
        guard let field = tokens.last else { return [] }
        if alias.hasSuffix("_failures") { return [["sum": ["requests": 0]]] }
        let now = Demo.now ?? .now
        if tokens.first == "dimensions" {
            let dimension = tokens[1]
            let measured = Array(tokens.dropFirst(2))
            func group(_ key: Any, _ value: Double) -> [String: Any] {
                var node: Any = value
                for name in measured.reversed() { node = [name: node] }
                var result = node as? [String: Any] ?? [:]
                result["dimensions"] = [dimension: key]
                return result
            }
            switch dimension {
            case "datetimeHour":
                let hour = Calendar.current.dateInterval(of: .hour, for: now)!.start
                let shape: [Double] = [38, 31, 26, 22, 20, 24, 33, 41, 52, 61, 66, 70, 72, 68, 64, 58, 52, 47, 44, 42, 40, 39, 37, 30]
                return (0..<24).map { index in
                    let at = hour.addingTimeInterval(Double(index - 23) * 3600)
                    let scale = field == "requests" ? 10.0 : 1000.0
                    return group(ISO8601DateFormatter().string(from: at), shape[(index + 9) % 24] * scale)
                }
            case "date":
                // D1 reads near (never past) 5M; the others scaled to their own daily allowances.
                let factors: [String: Double] = ["requests": 0.011, "rowsWritten": 0.004]
                let factor: Double = factors[field] ?? 1
                let values: [Double] = [2.1e6, 2.6e6, 3.2e6, 3.75e6, 1.1e6, 0.86e6, 0.91e6].map { $0 * factor }
                return (0..<7).map { index in
                    let day = Calendar.current.date(byAdding: .day, value: index - 6, to: now)!
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    formatter.timeZone = TimeZone(identifier: "UTC")
                    return group(formatter.string(from: day), values[index])
                }
            case "query":
                return [("SELECT … FROM standings ORDER BY tokens DESC LIMIT ?", 396_000),
                        ("SELECT … FROM daily_tokens WHERE member_id = ? AND day >= ?", 90_000),
                        ("INSERT INTO standings … ON CONFLICT DO UPDATE", 74_000),
                        ("SELECT … FROM devices WHERE code = ?", 1_200)].map { group($0.0, $0.1) }
            default:
                return [("success", 9_781), ("scriptThrewException", 21), ("clientDisconnected", 9), ("exceededResources", 3)]
                    .map { group($0.0, $0.1) }
            }
        }
        if tokens == ["status"] { return (0..<24).map { _ in ["status": "success"] } }
        let value = numbers[field] ?? 0
        var node: Any = value
        for key in tokens.reversed() { node = [key: node] }
        return [node as? [String: Any] ?? [:]]
    }

    func accounts() async throws -> [AccountSummary] { [AccountSummary(id: "demo", name: "acme")] }
    func subscriptions(account: String) async throws -> [Subscription] { [] }
    func invoices(account: String) async throws -> [Invoice] { [] }
    func scripts(account: String) async throws -> [String] { ["api", "leaderboard"] }
    func deployments(account: String, script: String) async throws -> [Deployment] {
        [Deployment(id: "d605dc93-demo", at: (Demo.now ?? .now).addingTimeInterval(-86_400 * 1.2))]
    }
}

/// Refuses every token as wrong: the Connect screen's refused state, for screenshots.
struct RefusingCloudflare: AnalyticsAPI, BillingAPI {
    func read(_ query: AnalyticsQuery) async throws -> AnalyticsAnswer { throw AnalyticsError.refused }
    func accounts() async throws -> [AccountSummary] { throw BillingError.refused }
    func subscriptions(account: String) async throws -> [Subscription] { [] }
    func invoices(account: String) async throws -> [Invoice] { [] }
    func scripts(account: String) async throws -> [String] { [] }
    func deployments(account: String, script: String) async throws -> [Deployment] { [] }
}

final class MemoryVault: TokenVault, @unchecked Sendable {
    var token: String?
    init(token: String?) { self.token = token }
    func save(_ token: String) throws { self.token = token }
    func load() -> String? { token }
    func delete() { token = nil }
}

final class MemorySettings: SettingsStore, @unchecked Sendable {
    var settings: Settings
    init(_ settings: Settings) { self.settings = settings }
    func load() -> Settings { settings }
    func save(_ settings: Settings) { self.settings = settings }
}

struct SilentNotifier: Notifier {
    func post(_ warning: Warning) async {}
}
