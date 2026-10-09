import SwiftUI
import AppKit
import Measures
import Limits
import Analytics
import Alerts
import Monitor

/// *Today*: the account strip, the closest limit, every limit, *Warn me at*, and the month.
struct TodayView: View {
    let account: Account
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AccountStrip(account: account, now: now)
            if let closest = account.closest(at: now) {
                Headline(limit: closest, now: now)
            } else {
                Text(account.lastProblem ?? "Reading your limits…").font(Pop.body(12)).foregroundStyle(Pop.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12).popCard()
            }
            SectionHeading(text: "Every limit today", trailing: "Open dashboard ↗") { NSWorkspace.shared.open(account.dashboardURL) }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(account.limits) { limit in
                    LimitCard(limit: limit, glyph: account.service(of: limit.id)?.look.glyph ?? "•", now: now)
                }
            }
            AlertsCard(account: account)
            if let bill = account.bill {
                MonthCard(account: account, bill: bill, now: now)
            }
        }
    }
}

/// *claudebar-leaderboard · LIVE · read 1 min ago* and the focus picker.
struct AccountStrip: View {
    let account: Account
    let now: Date

    var body: some View {
        let freshness = account.freshness(at: now)
        HStack(spacing: 10) {
            Circle().fill(freshness == .live ? Pop.mintDeep : Pop.butter).frame(width: 12, height: 12)
                .overlay(Circle().stroke(Pop.ink, lineWidth: 2))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(account.focus.value ?? "All Workers").font(Pop.label(13)).foregroundStyle(Pop.ink).lineLimit(1)
                    Chip(text: freshness == .live ? "LIVE" : freshness == .stale ? "STALE" : "—",
                         fill: freshness == .live ? Pop.mint : Pop.butter)
                }
                Text(status(freshness)).font(Pop.mono(10)).foregroundStyle(Pop.muted).lineLimit(1)
            }
            Spacer(minLength: 4)
            Menu {
                Button("All Workers") { account.focus = .everything }
                Divider()
                ForEach(account.workers, id: \.self) { worker in
                    Button(worker) { account.focus = Focus(dimension: "scriptName", value: worker) }
                }
            } label: {
                Text("\(account.focus.value ?? "All") ▾").font(Pop.label(11)).foregroundStyle(Pop.ink)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Pop.paper))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Pop.ink, lineWidth: 2))
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .popCard(freshness == .live ? Color(red: 0.957, green: 1, blue: 0.973) : Pop.butterSoft)
    }

    private func status(_ freshness: Account.Freshness) -> String {
        guard let lastRead = account.lastRead else { return account.lastProblem ?? "reading…" }
        let read = "read \(Say.ago(lastRead, now: now))"
        if let problem = account.lastProblem { return "\(problem) · \(read)" }
        return read
    }
}

/// *CLOSEST TO THE LIMIT · D1 rows read · 18% of 5M · on pace for 31% by midnight*.
struct Headline: View {
    let limit: Limit
    let now: Date

    var body: some View {
        let percent = limit.percent(at: now) ?? Percent(0)
        let level = limit.level(at: now) ?? .ok
        let pace = limit.pace(at: now)
        let usage = limit.current(at: now)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("⛁").font(Pop.label(9)).frame(width: 18, height: 18)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Pop.edgeSoft))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Pop.ink, lineWidth: 2))
                Text(limit.definition.name.uppercased() + (usage?.period != nil ? " · TODAY" : "")).font(Pop.label(10)).tracking(0.6)
            }
            .padding(.top, 4)
            Outlined(text: "\(percent.rounded)% of \(limit.allowance.amount.short)", size: 32).padding(.top, 4)
            Text(sentence(pace: pace, usage: usage)).font(Pop.body(11.5)).foregroundStyle(Pop.muted)
            DayBar(used: percent.value / 100, pace: (pace?.atPeriodEnd.value ?? percent.value) / 100).padding(.top, 6)
            HStack {
                Text(usage?.period.map { "\(Say.clock($0.start)) UTC" } ?? "")
                Spacer()
                Text("now \(Say.clock(now))")
                Spacer()
                Text("\(limit.allowance.amount.short) · allowance")
            }
            .font(Pop.label(9.5)).foregroundStyle(Pop.muted)
            HStack(spacing: 8) {
                Stat(value: pace.map { "\($0.atPeriodEnd.rounded)%" } ?? "—", label: "Pace at reset")
                Stat(value: pace?.reaches(Percent(90)).map { Say.clock($0) } ?? "—", label: "Crosses 90%")
                Stat(value: usage?.period.map { Say.until($0.end, now: now) } ?? "—", label: "Until reset")
            }
            .padding(.top, 6)
        }
        .padding(12)
        .popCard(level == .actNow ? Pop.coralSoft : Pop.paper)
        .overlay(alignment: .topTrailing) {
            Sticker(text: level == .actNow ? "ACT NOW" : level == .watch ? "WATCH" : "CLOSEST TO THE LIMIT",
                    fill: level == .actNow ? Pop.coral : Pop.butter).offset(x: -10, y: -11)
        }
        .padding(.top, 6)
    }

    private func sentence(pace: Pace?, usage: Usage?) -> String {
        guard let usage else { return "" }
        let used = "\(usage.used.short) used" + (usage.period.map { " since \(Say.clock($0.start)) UTC" } ?? "")
        guard let pace else { return usage.period == nil ? used : "\(used) · too early to tell the pace" }
        if let crossing = pace.reaches(Percent(100)) {
            return "\(used) · runs out at \(Say.clock(crossing)) UTC at this pace"
        }
        return "\(used) · on pace for \(pace.atPeriodEnd.rounded)% by the reset"
    }
}

struct DayBar: View {
    let used: Double
    let pace: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(Pop.paper)
                Rectangle()
                    .fill(Pop.edgeSoft)
                    .overlay(StripeFill().stroke(Color(red: 1, green: 0.816, blue: 0.651), lineWidth: 2.5).clipped())
                    .frame(width: geometry.size.width * min(max(pace, 0), 1))
                Rectangle().fill(Pop.edge).frame(width: max(2, geometry.size.width * min(max(used, 0), 1)))
                    .overlay(alignment: .trailing) { Rectangle().fill(Pop.ink).frame(width: 2) }
            }
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Pop.ink, lineWidth: 2))
        }
        .frame(height: 20)
    }
}

/// Diagonal stripes: the part the pace adds.
struct StripeFill: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = -rect.height
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: rect.height))
            path.addLine(to: CGPoint(x: x + rect.height, y: 0))
            x += 7
        }
        return path
    }
}

struct Stat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(Pop.display(16)).foregroundStyle(Pop.ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(label.uppercased()).font(Pop.label(8.5)).tracking(0.4).foregroundStyle(Pop.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.984, green: 0.969, blue: 0.945)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Pop.ink, lineWidth: 2))
    }
}

/// A card in *Every limit today*.
struct LimitCard: View {
    let limit: Limit
    let glyph: String
    let now: Date

    var body: some View {
        let percent = limit.percent(at: now)
        let level = limit.level(at: now) ?? .ok
        let usage = limit.current(at: now)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 7) {
                Badge(glyph: glyph, fill: Pop.edgeSoft, size: 24)
                VStack(alignment: .leading, spacing: 0) {
                    Text(limit.definition.name).font(Pop.label(12)).foregroundStyle(Pop.ink).lineLimit(1)
                    Text(allowance).font(Pop.label(9)).foregroundStyle(Pop.muted).lineLimit(1)
                }
                Spacer(minLength: 2)
                Chip(text: percent == nil ? "—" : level.word, fill: percent == nil ? Pop.well : level.color)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(usage?.used.short ?? "—").font(Pop.display(20)).foregroundStyle(Pop.ink)
                if let percent { Text("\(percent.rounded)%").font(Pop.label(10)).foregroundStyle(Pop.muted) }
            }
            .padding(.top, 6)
            Gauge(fraction: (percent?.value ?? 0) / 100, fill: level.color).padding(.top, 6)
            Rectangle().fill(Pop.dash).frame(height: 2).padding(.top, 7)
            HStack {
                Text(footnote(usage)).lineLimit(1)
                Spacer()
                if let percent, limit.runsOut { Text("\(max(0, 100 - percent.rounded))% left").foregroundStyle(Pop.ink) }
            }
            .font(Pop.label(9.5)).foregroundStyle(Pop.muted).padding(.top, 5)
        }
        .padding(10)
        .popCard(level.soft, shadow: level == .actNow ? Pop.coral : Pop.ink)
    }

    private var allowance: String {
        switch limit.allowance {
        case .perDay(let amount): "\(amount.short) / day"
        case .perMonth(let amount): "\(amount.short) / month"
        case .perInvocation(let amount): "\(amount.short) / invocation"
        case .total(let amount): "\(amount.short) total"
        }
    }

    private func footnote(_ usage: Usage?) -> String {
        if case .perInvocation = limit.allowance {
            let stopped = usage?.failures ?? 0
            return stopped == 0 ? "p99 · none stopped" : "p99 · \(stopped) stopped"
        }
        guard let period = usage?.period else { return usage == nil ? "not read yet" : "never resets" }
        return "resets in \(Say.until(period.end, now: now))"
    }
}

/// *Warn me at 50% 75% 90% · pace · Notify*.
struct AlertsCard: View {
    let account: Account

    var body: some View {
        let settings = account.alerts.settings
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WARN ME AT").font(Pop.label(10)).tracking(0.6)
                Spacer()
                PopSwitch(isOn: settings.isOn) { account.setNotify(!settings.isOn) }
                Text("Notify").font(Pop.label(10.5))
            }
            HStack(spacing: 6) {
                ForEach(AlertSettings.offered, id: \.self) { level in
                    let on = settings.levels.contains(level)
                    Button { account.setLevel(level, on: !on) } label: {
                        Text("\(level)%").font(Pop.label(11)).foregroundStyle(Pop.ink)
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(Capsule().fill(on ? (level >= 90 ? Pop.coral : level >= 75 ? Pop.butter : Pop.mint) : Pop.paper))
                            .overlay(Capsule().stroke(Pop.ink, style: StrokeStyle(lineWidth: 2, dash: on ? [] : [3, 2])))
                            .opacity(on ? 1 : 0.55)
                    }
                    .buttonStyle(.plain)
                }
                Button { account.setPace(!settings.pace) } label: {
                    Text("⏱ pace").font(Pop.label(11)).foregroundStyle(Pop.ink)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Capsule().fill(settings.pace ? Pop.edgeSoft : Pop.paper))
                        .overlay(Capsule().stroke(Pop.ink, style: StrokeStyle(lineWidth: 2, dash: settings.pace ? [] : [3, 2])))
                        .opacity(settings.pace ? 1 : 0.55)
                }
                .buttonStyle(.plain).padding(.leading, 6)
            }
            Text("One notification per limit per level per reset. Pace warns early when the current rate would cross 90% before the reset.")
                .font(Pop.body(10.5)).foregroundStyle(Pop.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .popCard()
        .opacity(settings.isOn ? 1 : 0.75)
    }
}
