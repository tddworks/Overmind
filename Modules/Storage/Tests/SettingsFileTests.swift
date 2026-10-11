import Foundation
import Testing
import Analytics
import Alerts
import Billing
import Monitor
@testable import Storage

@Suite
struct SettingsFileTests {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("overmind-\(UUID().uuidString)")

    @Test func `should remember the account, the focus, the services watched and the warnings already sent across a relaunch`() {
        let saved = Settings(account: AccountSummary(id: "acc1", name: "Acme"),
                             focus: Focus(dimension: "scriptName", value: "leaderboard"),
                             alerts: AlertSettings(levels: [90], pace: false, isOn: true),
                             sent: [Warning.Key(limit: "d1.rowsRead", mark: .level(75), period: Date(timeIntervalSince1970: 0))],
                             watch: ["d1": false])
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

@Suite
struct OlderSettingsFileTests {
    @Test func `should read every 5 minutes from a settings file written before the interval could be chosen`() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("overmind-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let older = #"{"account":{"id":"acc1","name":"Acme"},"focus":{},"alerts":{"levels":[90],"pace":false,"isOn":true},"sent":[]}"#
        try Data(older.utf8).write(to: folder.appendingPathComponent("settings.json"))

        let settings = Storage.makeSettings(folder: folder).load()

        #expect(settings.account == AccountSummary(id: "acc1", name: "Acme"))
        #expect(settings.alerts.levels == [90])
        #expect(settings.interval == 5)
    }
}
