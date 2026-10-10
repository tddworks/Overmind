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

    private var readingSection: some View {
        SettingsSection(title: "Reading") {
            SettingsRow(title: "Read every", note: "STALE after two missed reads") {
                HStack(spacing: 0) {
                    ForEach(Array(Account.intervals.enumerated()), id: \.offset) { index, minutes in
                        let on = Int(account.interval / 60) == minutes
                        Button { account.setInterval(minutes: minutes) } label: {
                            Text(index == 0 ? "\(minutes) min" : "\(minutes)").font(Pop.label(11))
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
