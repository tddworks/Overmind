import Foundation
import Monitor

/// The `SettingsStore` port over one JSON file. A file that doesn't read gives the defaults,
/// never a crash.
struct JSONSettingsFile: SettingsStore {
    let file: URL

    func load() -> Settings {
        guard let data = try? Data(contentsOf: file), let settings = try? JSONDecoder().decode(Settings.self, from: data) else {
            return Settings()
        }
        return settings
    }

    func save(_ settings: Settings) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(settings) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }
}
