import SwiftUI
import AppKit
import Measures
import Services
import Limits
import Analytics
import Billing
import Monitor

extension Level {
    /// A level drawn: mint, butter, coral.
    var color: Color {
        switch self {
        case .ok: Pop.mint
        case .watch: Pop.butter
        case .actNow: Pop.coral
        }
    }

    var soft: Color {
        switch self {
        case .ok: Pop.paper
        case .watch: Pop.butterSoft
        case .actNow: Pop.coralSoft
        }
    }
}

/// The popover: the header, the tabs (Today, one per service, Bill) and the footer
/// (design-concept/edgemeter-pop.html). Renders the Account and tells it what happened.
struct PopoverView: View {
    let account: Account
    @Environment(\.openSettings) private var openSettings
    @State var tab: String = "today"
    /// Off for screenshots, which draw the whole tab.
    var scrolls = true
    /// For screenshots: the Bill's chosen plan card.
    var billChoice: String? = nil

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let now = Demo.now ?? timeline.date
            VStack(alignment: .leading, spacing: 12) {
                header(now)
                switch account.phase {
                case .connected:
                    tabs
                    CappedScroll(maxHeight: scrolls ? 600 : .infinity) {
                        switch tab {
                        case "today": TodayView(account: account, now: now)
                        case "bill": BillView(account: account, now: now, chosen: billChoice)
                        default: ServiceView(account: account, serviceID: tab, now: now)
                        }
                    }
                    .task(id: tab) { await open(tab, now: now) }
                    footer(now)
                default:
                    ConnectView(account: account, now: now)
                }
            }
            .padding(14)
            .frame(width: 400)
            .background(Pop.cream)
        }
    }

    private func header(_ now: Date) -> some View {
        HStack(spacing: 9) {
            Badge(glyph: "☁", fill: Pop.edge, size: 34, foreground: .white)
                .background(RoundedRectangle(cornerRadius: 10).fill(Pop.ink).offset(x: 2, y: 2))
            VStack(alignment: .leading, spacing: 0) {
                Text("Edge Meter").font(Pop.display(21)).foregroundStyle(Pop.ink)
                Text(account.summary.map { "\($0.name) · Cloudflare account" } ?? "Cloudflare usage and billing")
                    .font(Pop.label(10)).foregroundStyle(Pop.muted).lineLimit(1)
            }
            Spacer(minLength: 4)
            if account.summary != nil { planChip(now) }
        }
    }

    private func planChip(_ now: Date) -> some View {
        let reset = account.limits.compactMap { account.plan.period(for: $0.id, at: now)?.end }.min()
        let text = account.plan.definition.name.uppercased() + (reset.map { " · resets in \(Say.until($0, now: now))" } ?? "")
        return Text(text).font(Pop.label(10)).foregroundStyle(Pop.ink).lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(account.plan.definition.subscription.amount > 0 ? Pop.sky : Pop.mint))
            .overlay(Capsule().stroke(Pop.ink, lineWidth: 2))
            .background(Capsule().fill(Pop.ink).offset(x: 2, y: 2))
    }

    private var tabs: some View {
        HStack(spacing: 7) {
            TabPill(icon: "◔", title: "Today", tint: Pop.edgeSoft, isOn: tab == "today") { tab = "today" }
            ForEach(account.services) { service in
                TabPill(icon: service.look.glyph, title: service.name, tint: Pop.named(service.look.color), isOn: tab == service.id) {
                    tab = service.id
                }
            }
            TabPill(icon: "$", title: "Bill", count: account.bill.map { Say.money($0.issued?.amount ?? $0.estimate) },
                    tint: Pop.mint, isOn: tab == "bill") { tab = "bill" }
        }
        .padding(.bottom, 2)
    }

    private func footer(_ now: Date) -> some View {
        HStack(spacing: 8) {
            PopButton(title: account.isRefreshing ? "↻ Reading…" : "↻ Refresh", fill: Pop.sky) {
                Task { await account.refresh(at: Demo.now ?? .now) }
            }
            PopButton(title: "☁ Dashboard ↗") { NSWorkspace.shared.open(account.dashboardURL) }
            Menu {
                Button("Settings…") {
                    // A menu bar app is never frontmost on its own: bring it forward first.
                    NSApp.activate()
                    openSettings()
                }
                Divider()
                Button("Disconnect this account") { account.disconnect() }
            } label: {
                Text("⚙").font(Pop.label(13)).foregroundStyle(Pop.ink).frame(width: 40).padding(.vertical, 7).popCard(Pop.mint, radius: 12)
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            PopButton(title: "✕", fill: Pop.coralSoft, width: 40) { NSApplication.shared.terminate(nil) }
        }
        .padding(.top, 2)
    }

    private func open(_ tab: String, now: Date) async {
        switch tab {
        case "today": if account.bill == nil { await account.openBill(at: now) }
        case "bill": await account.openBill(at: now)
        default: await account.open(tab, at: now)
        }
    }
}

/// Its content's own height, up to `maxHeight`; past that it scrolls. Keeps the popover on a
/// laptop screen without padding short tabs.
struct CappedScroll<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder let content: Content
    @State private var height: CGFloat = 0

    var body: some View {
        if maxHeight == .infinity {
            content.padding(.top, 10)    // screenshots: ImageRenderer draws nothing inside a ScrollView
        } else {
            scroll.padding(.leading, -2).padding(.top, -10)
        }
    }

    private var scroll: some View {
        ScrollView(.vertical) {
            content
                // Room for the cards' outlines and hard shadows, which reach past their frames
                // and a ScrollView clips: 2.5 pt strokes, 3 pt shadows, the tilted sticker.
                .padding(.leading, 2).padding(.top, 12).padding(.trailing, 5).padding(.bottom, 6)
                .background(GeometryReader { geometry in
                    Color.clear.onAppear { height = geometry.size.height }
                        .onChange(of: geometry.size.height) { _, new in height = new }
                })
        }
        .scrollIndicators(.automatic)
        .frame(height: min(max(height, 1), maxHeight))
    }
}

/// A section heading: "EVERY LIMIT TODAY".
struct SectionHeading: View {
    let text: String
    var trailing: String? = nil
    var tell: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(text.uppercased()).font(Pop.label(10)).tracking(0.6).foregroundStyle(Pop.ink)
            Spacer()
            if let trailing {
                Button(trailing) { tell?() }.buttonStyle(.plain).font(Pop.label(11)).foregroundStyle(Pop.grape)
            }
        }
        .padding(.horizontal, 2)
    }
}
