import Foundation
import Testing
import Analytics
import Alerts
import Billing
import Monitor
@testable import Storage

@Suite
struct SettingsFileTests {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("edgemeter-\(UUID().uuidString)")

    @Test func `should remember the account, the focus and the warnings already sent across a relaunch`() {
        let saved = Settings(account: AccountSummary(id: "acc1", name: "Acme"),
                             focus: Focus(dimension: "scriptName", value: "leaderboard"),
                             alerts: AlertSettings(levels: [90], pace: false, isOn: true),
                             sent: [Warning.Key(limit: "d1.rowsRead", mark: .level(75), period: Date(timeIntervalSince1970: 0))])
        Storage.makeSettings(folder: folder).save(saved)

        #expect(Storage.makeSettings(folder: folder).load() == saved)
    }

    @Test func `should start from the defaults when there is no settings file yet`() {
        #expect(Storage.makeSettings(folder: folder).load() == Settings())
    }

    @Test func `should start from the defaults when the settings file is damaged`() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: folder.appendingPathComponent("settings.json"))
        #expect(Storage.makeSettings(folder: folder).load() == Settings())
    }
}
