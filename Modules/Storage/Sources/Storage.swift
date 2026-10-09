import Foundation
import Monitor

/// Storage — where Edge Meter keeps things: the token in the Keychain, the choices in
/// `~/.edgemeter/settings.json`. It implements Monitor's ports.
public enum Storage {
    public static func makeVault() -> any TokenVault { KeychainTokenVault() }

    public static func makeSettings(folder: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".edgemeter")) -> any SettingsStore {
        JSONSettingsFile(file: folder.appendingPathComponent("settings.json"))
    }
}
