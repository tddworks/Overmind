import ServiceManagement
import Diagnostics

/// *Start at login*, over the system's login items. The system owns it; Edge Meter only asks.
@MainActor @Observable
final class LoginItem {
    private(set) var isOn = SMAppService.mainApp.status == .enabled
    private(set) var problem: String?

    func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            problem = nil
        } catch {
            problem = "macOS didn't allow it. Check System Settings → General → Login Items."
            AppLog.monitor.error("login item change failed")
        }
        isOn = SMAppService.mainApp.status == .enabled
    }
}
