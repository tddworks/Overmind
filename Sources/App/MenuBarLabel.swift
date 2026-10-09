import SwiftUI
import Limits
import Monitor

/// "☁ D1 18%" — the closest limit; a mark once anything needs watching. It redraws when the
/// account changes; a TimelineView here makes MenuBarExtra update in a loop.
struct MenuBarLabel: View {
    let account: Account

    var body: some View {
        let state = account.menuBar(at: Demo.now ?? account.lastRead ?? .now)
        switch (account.phase, state.level) {
        case (.refused, _): Text("☁ ⚠︎")  // any refusal
        case (.connected, .actNow): Text("☁ ⚠︎ \(state.text)")
        case (.connected, .watch): Text("☁ ◐ \(state.text)")
        case (.connected, _): Text(state.text.isEmpty ? "☁" : "☁ \(state.text)")
        default: Text("☁")
        }
    }
}
