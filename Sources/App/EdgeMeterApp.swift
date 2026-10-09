import SwiftUI
import AppKit
import Services
import Plans
import Analytics
import Billing
import Alerts
import Monitor
import Storage

/// The composition root: builds every module once and starts the refresher. Names no
/// Cloudflare product.
@main
struct EdgeMeterApp: App {
    @State private var account: Account
    private let refresher: Refresher

    init() {
        let account: Account
        if Demo.isOn {
            account = Demo.account()
        } else {
            let vault = Storage.makeVault()
            let bearer: @Sendable () async throws -> String = {
                guard let token = vault.load() else { throw TokenUnavailable() }
                return token
            }
            account = (try? Account(services: .builtIns(), plans: .builtIns(), analytics: Analytics.make(bearer: bearer),
                                    billing: Billing.make(bearer: bearer), vault: vault, settings: Storage.makeSettings(),
                                    notifier: Alerts.makeNotifier())) ?? Demo.account()
        }
        _account = State(initialValue: account)
        refresher = Refresher(account: account, clock: { Demo.now ?? .now })
        refresher.start()
        if let folder = ProcessInfo.processInfo.environment["EDGEMETER_SNAPSHOT_DIR"] { Snapshots.schedule(account, into: folder) }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(account: account)
        } label: {
            MenuBarLabel(account: account)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Screenshots of each tab on demo data (EDGEMETER_DEMO=1 EDGEMETER_SNAPSHOT_DIR=…): written
/// after a pause, then the app quits.
@MainActor
enum Snapshots {
    static func schedule(_ account: Account, into folder: String) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            await account.openBill(at: Demo.now ?? .now)
            let tabs = ["today"] + account.services.map(\.id) + ["bill"]
            for tab in tabs {
                if tab != "today" && tab != "bill" { await account.open(tab, at: Demo.now ?? .now) }
                write(PopoverView(account: account, tab: tab, scrolls: false), to: folder, name: tab)
            }
            let fresh = try! Account(services: .builtIns(), plans: .builtIns(), analytics: DemoCloudflare(), billing: DemoCloudflare(),
                                     vault: MemoryVault(token: nil), settings: MemorySettings(Settings()), notifier: SilentNotifier())
            write(PopoverView(account: fresh, scrolls: false), to: folder, name: "connect")
            let refused = try! Account(services: .builtIns(), plans: .builtIns(), analytics: RefusingCloudflare(),
                                       billing: RefusingCloudflare(), vault: MemoryVault(token: nil),
                                       settings: MemorySettings(Settings()), notifier: SilentNotifier())
            await refused.connect(token: "wrong", at: .now)
            write(PopoverView(account: refused, scrolls: false), to: folder, name: "connect-refused")
            NSApplication.shared.terminate(nil)
        }
    }

    static func write(_ view: some View, to folder: String, name: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: folder).appending(path: "popover-\(name).png"))
        }
    }
}
