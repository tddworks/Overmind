import SwiftUI
import AppKit
import Billing
import Monitor

/// *Connect Cloudflare*: paste a read-only API token (journeys 1–3, 17).
struct ConnectView: View {
    let account: Account
    let now: Date
    @State private var token = ""

    static let createToken = URL(string: "https://dash.cloudflare.com/profile/api-tokens")!

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch account.phase {
            case .choosing(let accounts):
                Text("Which account?").font(Pop.display(20))
                Text("This token can read more than one.").font(Pop.body(11.5)).foregroundStyle(Pop.muted)
                ForEach(accounts) { summary in
                    PopButton(title: summary.name) { Task { await account.choose(summary, at: .now) } }
                }
            default:
                Text("Connect Cloudflare").font(Pop.display(20))
                Text("Paste an API token. Edge Meter only reads; it can't deploy, change or delete anything.")
                    .font(Pop.body(11.5)).foregroundStyle(Pop.muted).fixedSize(horizontal: false, vertical: true)
                if case .refused(let refusal) = account.phase {
                    Notice(text: Self.words(refusal), fill: Pop.coralSoft)
                } else if let problem = account.lastProblem {
                    Notice(text: problem, fill: Pop.butterSoft)
                }
                Text("API TOKEN").font(Pop.label(10)).tracking(0.5).padding(.top, 4)
                SecureField("Paste the token", text: $token)
                    .textFieldStyle(.plain).font(Pop.mono(12))
                    .padding(.horizontal, 9).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.984, green: 0.969, blue: 0.945)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Pop.ink, lineWidth: 2))
                    .onSubmit(connect)
                Text("TOKEN NEEDS").font(Pop.label(10)).tracking(0.5).padding(.top, 4)
                VStack(alignment: .leading, spacing: 5) {
                    Permission(name: "Account Analytics", note: "READ · the limits and charts")
                    Permission(name: "Workers Scripts", note: "READ · Workers and deployments")
                    Permission(name: "Billing", note: "READ · the plan and invoices — optional")
                }
                HStack(spacing: 8) {
                    PopButton(title: "Create a token ↗") { NSWorkspace.shared.open(Self.createToken) }
                    PopButton(title: account.phase == .connecting ? "Connecting…" : "Connect", fill: Pop.mint, tell: connect)
                }
                .padding(.top, 6)
                Text("Kept in your Keychain. Read every 5 minutes.").font(Pop.body(10.5)).foregroundStyle(Pop.muted)
                HStack {
                    Spacer()
                    Button("Quit Edge Meter") { NSApplication.shared.terminate(nil) }.buttonStyle(.plain)
                        .font(Pop.label(10.5)).foregroundStyle(Pop.muted)
                }
            }
        }
        .padding(14)
        .popCard()
    }

    static func words(_ refusal: Account.Refusal) -> String {
        switch refusal {
        case .invalidToken: "Cloudflare refused the token (401): it is wrong, revoked or expired. Check it, or make a new one."
        case .cannotSeeAccount: "The token works, but Cloudflare shows it no account (403). Give it access to your account."
        case .cannotReadAnalytics: "The token can't read usage (403). Add Account Analytics: Read to it."
        }
    }

    private func connect() {
        let pasted = token
        token = ""
        Task { await account.connect(token: pasted, at: .now) }
    }
}

/// A message that wraps, never cut off.
struct Notice: View {
    let text: String
    let fill: Color

    var body: some View {
        Text(text).font(Pop.label(11)).foregroundStyle(Pop.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
            .popCard(fill, radius: 10)
    }
}

struct Permission: View {
    let name: String
    let note: String

    var body: some View {
        HStack(spacing: 7) {
            Text("✓").font(Pop.label(9)).frame(width: 16, height: 16)
                .background(RoundedRectangle(cornerRadius: 5).fill(Pop.mint))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Pop.ink, lineWidth: 2))
            Text(name).font(Pop.label(11))
            Spacer()
            Text(note).font(Pop.label(9.5)).foregroundStyle(Pop.muted)
        }
    }
}
