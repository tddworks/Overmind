import SwiftUI

// The composition root. Until slice 4 (docs/status.md) the popover only says what's coming;
// the screens are drawn in design-concept/edgemeter-pop.html.
@main
struct EdgeMeterApp: App {
    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 6) {
                Text("Edge Meter").font(.headline)
                Text("Cloudflare usage and billing, read-only.").font(.caption)
                Divider()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .padding(14)
            .frame(width: 260, alignment: .leading)
        } label: {
            Image(systemName: "cloud")
        }
        .menuBarExtraStyle(.window)
    }
}
