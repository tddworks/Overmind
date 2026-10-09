import SwiftUI
import Sparkle
import Diagnostics

/// Updates through Sparkle (docs/features/updates): the only code that links it. Off in demo
/// mode and when not run from an app bundle with a feed.
@MainActor @Observable
final class Updater {
    private let controller: SPUStandardUpdaterController?

    init(enabled: Bool) {
        let bundle = Bundle.main
        let usable = enabled && bundle.bundlePath.hasSuffix(".app") && bundle.infoDictionary?["SUFeedURL"] != nil
        controller = usable ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil) : nil
        if !usable { AppLog.monitor.info("updates are off in this copy") }
    }

    var isAvailable: Bool { controller != nil }

    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    var lastChecked: Date? { controller?.updater.lastUpdateCheckDate }

    /// *Check now*: Sparkle's own window, in front.
    func checkNow() {
        guard let controller, controller.updater.canCheckForUpdates else { return }
        NSApp.activate()
        controller.checkForUpdates(nil)
    }

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}
