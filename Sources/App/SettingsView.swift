import SwiftUI
import Analytics
import Alerts
import Monitor

/// The Settings window (design-concept/overmind-pop.html → Settings): renders the Account and
/// tells it, like the popover; changes save at once.
struct SettingsView: View {
    let account: Account
    let loginItem: LoginItem
    let updater: Updater

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                accountSection
                watchingSection
                readingSection
                warningsSection
                generalSection
            }
            .padding(16)
        }
        .frame(width: 520, height: 600)
        .background(Pop.cream)
    }

    private var accountSection: some View {
        SettingsSection(title: "Account") {
            if let summary = account.summary {
                SettingsRow(title: summary.name, note: "Cloudflare account · the token is in your Keychain") {
                    Chip(text: account.plan.definition.name.uppercased(), fill: Pop.mint)
                    SmallButton(title: "Disconnect") { account.disconnect() }
                }
                SettingsRow(title: "Worker in focus", note: "the D1 and Worker tabs; limits always count every Worker") {
                    Menu {
                        Button("All Workers") { account.focus = .everything }
                        Divider()
                        ForEach(account.workers, id: \.self) { worker in
                            Button(worker) { account.focus = Focus(dimension: "scriptName", value: worker) }
                        }
                    } label: {
                        Text("\(account.focus.value ?? "All Workers") ▾").font(Pop.label(11)).foregroundStyle(Pop.ink)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Pop.paper))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Pop.ink, lineWidth: 2))
                    }
                    .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                }
            } else {
                SettingsRow(title: "Not connected", note: "connect from the ☁ menu bar item") { EmptyView() }
            }
        }
    }

    /// *Worker ☑ · D1 ☑ · KV ☐* (law 21): the last switch on is dimmed and stays on.
    private var watchingSection: some View {
        SettingsSection(title: "Watching") {
            ForEach(account.services) { service in
                let on = account.isWatching(service.id)
                let locked = on && !account.canUnwatch(service.id)
                SettingsRow(title: "\(service.look.glyph)  \(service.name)",
                            note: locked ? "Overmind watches at least one service"
                                : account.summary != nil && !account.isCounted(service.id) ? "not on this account's plans"
                                : service.limits.map(\.name).joined(separator: " · ")) {
                    PopSwitch(isOn: on) {
                        if on { account.unwatch(service.id) } else { Task { await account.watch(service.id, at: Demo.now ?? .now) } }
                    }
                    .opacity(locked ? 0.45 : 1)
                    .disabled(locked)
                }
                .opacity(on ? 1 : 0.6)
            }
            Text("A service you don't watch is never read: no tab, no card, no warning, no line in the Bill.")
                .font(Pop.body(10.5)).foregroundStyle(Pop.muted).padding(.top, 6)
        }
    }

    private var readingSection: some View {
        SettingsSection(title: "Reading") {
            SettingsRow(title: "Read every", note: "STALE after two missed reads") {
                Segments(options: Account.intervals.enumerated().map { index, minutes in (index == 0 ? "\(minutes) min" : "\(minutes)", minutes) },
                         chosen: Int(account.interval / 60)) { account.setInterval(minutes: $0) }
            }
        }
    }

    private var warningsSection: some View {
        let settings = account.alerts.settings
        return SettingsSection(title: "Warnings") {
            SettingsRow(title: "Warn me at", note: "once per limit, per level, per reset") {
                ForEach(AlertSettings.offered, id: \.self) { level in
                    let on = settings.levels.contains(level)
                    Button { account.setLevel(level, on: !on) } label: {
                        Text("\(level)%").font(Pop.label(11)).foregroundStyle(Pop.ink)
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .background(Capsule().fill(on ? (level >= 90 ? Pop.coral : level >= 75 ? Pop.butter : Pop.mint) : Pop.paper))
                            .overlay(Capsule().stroke(Pop.ink, style: StrokeStyle(lineWidth: 2, dash: on ? [] : [3, 2])))
                            .opacity(on ? 1 : 0.55)
                    }
                    .buttonStyle(.plain)
                }
            }
            SettingsRow(title: "Warn on pace", note: "when the rate would cross 90% before the reset") {
                PopSwitch(isOn: settings.pace) { account.setPace(!settings.pace) }
            }
            SettingsRow(title: "Notifications", note: nil) {
                PopSwitch(isOn: settings.isOn) { account.setNotify(!settings.isOn) }
            }
        }
    }

    private var generalSection: some View {
        SettingsSection(title: "General") {
            SettingsRow(title: "Menu bar shows",
                        note: account.menuBarShows == .iconOnly ? "☁ alone; ☁ ◐ at WATCH, ☁ ⚠︎ at ACT NOW" : "☁ D1 18% — the limit closest to running out") {
                Segments(options: [("Closest limit", MenuBarStyle.closestLimit), ("Icon only", .iconOnly)],
                         chosen: account.menuBarShows) { account.setMenuBar($0) }
            }
            SettingsRow(title: "Start at login", note: loginItem.problem) {
                PopSwitch(isOn: loginItem.isOn) { loginItem.set(!loginItem.isOn) }
            }
            SettingsRow(title: "Check for updates automatically", note: updateNote) {
                if updater.isAvailable {
                    PopSwitch(isOn: updater.automaticallyChecks) { updater.automaticallyChecks.toggle() }
                    SmallButton(title: "Check now") { updater.checkNow() }
                }
            }
        }
    }

    private var updateNote: String {
        guard updater.isAvailable else { return "Overmind \(Updater.version) · updates are off in this copy" }
        guard let checked = updater.lastChecked else { return "Overmind \(Updater.version) · not checked yet" }
        return "Overmind \(Updater.version) · last checked \(Say.ago(checked, now: .now))"
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased()).font(Pop.label(10)).tracking(0.6).padding(.bottom, 6)
            content
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .popCard()
    }
}

struct SettingsRow<Trailing: View>: View {
    let title: String
    let note: String?
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Pop.label(12.5)).foregroundStyle(Pop.ink)
                if let note { Text(note).font(Pop.body(10.5)).foregroundStyle(Pop.muted).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) { trailing }
        }
        .padding(.vertical, 7)
        .overlay(alignment: .top) { Rectangle().fill(Pop.dash).frame(height: 2) }
    }
}

/// A row of choices, one on: *Closest limit · Icon only*.
struct Segments<Value: Equatable>: View {
    let options: [(String, Value)]
    let chosen: Value
    let tell: (Value) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let on = option.1 == chosen
                Button { tell(option.1) } label: {
                    Text(option.0).font(Pop.label(11))
                        .foregroundStyle(on ? .white : Pop.ink)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(on ? Pop.grape : Pop.paper)
                        .overlay(alignment: .leading) {
                            if index > 0 { Rectangle().fill(Pop.ink).frame(width: 2) }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Pop.ink, lineWidth: 2))
    }
}

struct SmallButton: View {
    let title: String
    let tell: () -> Void

    var body: some View {
        Button(action: tell) {
            Text(title).font(Pop.label(11)).foregroundStyle(Pop.ink)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 10).fill(Pop.paper))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Pop.ink, lineWidth: 2))
                .background(RoundedRectangle(cornerRadius: 10).fill(Pop.ink).offset(x: 2, y: 2))
        }
        .buttonStyle(.plain)
    }
}
