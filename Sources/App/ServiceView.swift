import SwiftUI
import Measures
import Services
import Limits
import Analytics
import Billing
import Monitor

/// A service's tab: its limits, then its charts for the focus, with deployment pins.
struct ServiceView: View {
    let account: Account
    let serviceID: String
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AccountStrip(account: account, now: now)
            if let breakdowns = account.breakdowns[serviceID] {
                ForEach(breakdowns) { breakdown in BreakdownCard(breakdown: breakdown, deployments: account.deployments) }
            } else {
                Text("Reading…").font(Pop.body(12)).foregroundStyle(Pop.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12).popCard()
            }
            let limits = account.limits(of: serviceID)
            if !limits.isEmpty {
                VStack(spacing: 0) {
                    ListHeading(title: "Limits", note: "the whole account")
                    ForEach(limits) { limit in
                        ListRow(label: limit.definition.name, note: allowance(limit),
                                value: limit.current(at: now)?.used.short ?? "—",
                                fraction: (limit.percent(at: now)?.value ?? 0) / 100, tint: (limit.level(at: now) ?? .ok).color)
                    }
                }
                .popCard()
            }
        }
    }

    private func allowance(_ limit: Limit) -> String {
        switch limit.allowance {
        case .perDay(let amount): "\(amount.short) a day"
        case .perMonth(let amount): "\(amount.short) a month"
        case .perInvocation(let amount): "\(amount.short) an invocation"
        case .total(let amount): "\(amount.short) in all"
        }
    }
}

struct BreakdownCard: View {
    let breakdown: Breakdown
    let deployments: [Deployment]

    var body: some View {
        switch breakdown.content {
        case .bars(let bars):
            VStack(alignment: .leading, spacing: 6) {
                Text(breakdown.title.uppercased()).font(Pop.label(10)).tracking(0.6)
                Bars(bars: bars, pins: pins(bars)).frame(height: 78).padding(.top, 8)
                HStack {
                    Text(bars.first.map { label($0.at, bars: bars) } ?? "")
                    Spacer()
                    Text(bars.last.map { label($0.at, bars: bars) } ?? "")
                }
                .font(Pop.label(9.5)).foregroundStyle(Pop.muted)
                if bars.isEmpty { Text("Nothing counted yet.").font(Pop.body(10.5)).foregroundStyle(Pop.muted) }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .popCard()
        case .rows(let rows):
            VStack(spacing: 0) {
                ListHeading(title: breakdown.title, note: "last 24 h")
                if rows.isEmpty {
                    Text("Nothing counted in the last 24 hours.").font(Pop.body(11)).foregroundStyle(Pop.muted)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }
                let peak = rows.map(\.value).max() ?? 1
                ForEach(Array(rows.prefix(6).enumerated()), id: \.offset) { _, row in
                    ListRow(label: row.label, value: Say.number(row.value), fraction: row.value / max(peak, 1), tint: Pop.edge, code: true)
                }
            }
            .popCard()
        }
    }

    /// A deployment pinned on the bar whose step holds it.
    private func pins(_ bars: [Bar]) -> [Int: String] {
        guard bars.count > 1 else { return [:] }
        let step = bars[1].at.timeIntervalSince(bars[0].at)
        var pins: [Int: String] = [:]
        for deployment in deployments {
            if let index = bars.firstIndex(where: { deployment.at >= $0.at && deployment.at < $0.at.addingTimeInterval(step) }) {
                pins[index] = deployment.short
            }
        }
        return pins
    }

    private func label(_ date: Date, bars: [Bar]) -> String {
        guard bars.count > 1, bars[1].at.timeIntervalSince(bars[0].at) < 86_400 else { return Say.day(date) }
        return Say.clock(date)
    }
}

/// Bars over time, the newest striped; a pin above the bar a deployment went live in.
struct Bars: View {
    let bars: [Bar]
    let pins: [Int: String]

    var body: some View {
        let peak = max(bars.map(\.value).max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(bars.enumerated()), id: \.offset) { index, bar in
                UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4)
                    .fill(index == bars.count - 1 ? Pop.edgeSoft : Pop.edge)
                    .overlay(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4).stroke(Pop.ink, lineWidth: 1.5))
                    .frame(height: max(3, 70 * bar.value / peak))
                    .overlay(alignment: .top) {
                        if let pin = pins[index] {
                            Text(pin).font(Pop.label(8)).foregroundStyle(.white).fixedSize()
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Pop.ink))
                                .offset(y: -16)
                        }
                    }
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .overlay(alignment: .bottom) { Rectangle().fill(Pop.ink).frame(height: 2) }
    }
}

struct ListHeading: View {
    let title: String
    var note: String? = nil

    var body: some View {
        HStack {
            Text(title.uppercased()).font(Pop.label(10)).tracking(0.6)
            Spacer()
            if let note { Text(note).font(Pop.label(10)).foregroundStyle(Pop.muted) }
        }
        .padding(.horizontal, 12).padding(.top, 9).padding(.bottom, 4)
    }
}

struct ListRow: View {
    let label: String
    var note: String? = nil
    let value: String
    var fraction: Double? = nil
    var tint: Color = Pop.edge
    var code = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    if code {
                        Text(label.replacingOccurrences(of: "\n", with: " ")).font(Pop.mono(10)).lineLimit(1).truncationMode(.tail)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Pop.well))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Pop.ink, lineWidth: 1.5))
                    } else {
                        Text(label).font(Pop.label(11.5)).lineLimit(1)
                    }
                    if let note { Text(note).font(Pop.label(9.5)).foregroundStyle(Pop.muted).fixedSize(horizontal: false, vertical: true) }
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(value).font(Pop.display(15)).foregroundStyle(Pop.ink)
                    if let fraction { Gauge(fraction: fraction, fill: tint, height: 7).frame(width: 70) }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            Rectangle().fill(Pop.dash).frame(height: 2).padding(.horizontal, 2)
        }
    }
}
