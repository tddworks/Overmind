import Foundation
import Mockable
import Analytics
import Alerts
import Billing

/// Keeps the API token: the Keychain, and nowhere else (CANONICAL law 15).
@Mockable
public protocol TokenVault: Sendable {
    func save(_ token: String) throws
    func load() -> String?
    func delete()
}

/// Keeps the person's choices and the sent-warnings log: `~/.overmind/settings.json`.
@Mockable
public protocol SettingsStore: Sendable {
    func load() -> Settings
    func save(_ settings: Settings)
}

/// The adapters couldn't get the token from the vault: the Keychain refused this build, or the
/// item is gone. Not Cloudflare's answer, so never shown as a refused token.
public struct TokenUnavailable: Error, Equatable, Sendable {
    public init() {}
}

/// The choices and the once-only log (CANONICAL §2). Never a token, never a reading.
public struct Settings: Sendable, Equatable, Codable {
    public var account: AccountSummary?
    public var focus: Focus
    /// Minutes between reads (law 17).
    public var interval: Int
    public var alerts: AlertSettings
    public var sent: Set<Warning.Key>

    public init(account: AccountSummary? = nil, focus: Focus = .everything, interval: Int = 5,
                alerts: AlertSettings = .standard, sent: Set<Warning.Key> = []) {
        self.account = account
        self.focus = focus
        self.interval = interval
        self.alerts = alerts
        self.sent = sent
    }

    /// A file from an older version lacks the newer keys: each falls back to its default, and
    /// the rest of the file still counts.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Settings()
        account = try container.decodeIfPresent(AccountSummary.self, forKey: .account)
        focus = (try? container.decodeIfPresent(Focus.self, forKey: .focus)) ?? defaults.focus
        interval = (try? container.decodeIfPresent(Int.self, forKey: .interval)) ?? defaults.interval
        alerts = (try? container.decodeIfPresent(AlertSettings.self, forKey: .alerts)) ?? defaults.alerts
        sent = (try? container.decodeIfPresent(Set<Warning.Key>.self, forKey: .sent)) ?? defaults.sent
    }
}
