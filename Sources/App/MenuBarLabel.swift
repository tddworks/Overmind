import SwiftUI
import Limits
import Monitor

/// "☁ D1 18%" — the closest limit; a mark once anything needs watching. It redraws when the
/// account changes; a TimelineView here makes MenuBarExtra update in a loop.
struct MenuBarLabel: View {
    let account: Account

    var body: some View {
        switch account.phase {
        case .refused: Text("☁ ⚠︎")  // any refusal, whatever the choice (law 22)
        case .connected:
            switch account.menuBar(at: Demo.now ?? account.lastRead ?? .now) {
            case .notReadYet: Text("☁")
            case .iconOnly(let level): Text("☁" + Self.mark(level))
            case .closest(let short, let percent, let level): Text("☁\(Self.mark(level)) \(short) \(percent.rounded)%")
            }
        default: Text("☁")
        }
    }

    /// ` ◐` at *WATCH*, ` ⚠︎` at *ACT NOW*.
    static func mark(_ level: Level) -> String {
        switch level {
        case .ok: ""
        case .watch: " ◐"
        case .actNow: " ⚠︎"
        }
    }
}
