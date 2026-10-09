import SwiftUI
import AppKit
import Measures
import Plans
import Billing
import Monitor

/// *Bill*: the month so far, then *If you upgraded*: a verdict, the plans as cards to choose,
/// and the chosen plan's month in detail (design-concept → Bill).
struct BillView: View {
    let account: Account
    let now: Date
    /// Which card is chosen: the view's own choice; the account's plan to begin with.
    @State private var chosen: String?

    init(account: Account, now: Date, chosen: String? = nil) {
        self.account = account
        self.now = now
        _chosen = State(initialValue: chosen)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let bill = account.bill {
                MonthCard(account: account, bill: bill, now: now, big: true)
                if !account.quotes.isEmpty {
                    SectionHeading(text: "If you upgraded")
                    VerdictCard(account: account, bill: bill)
                    HStack(alignment: .top, spacing: 10) {
                        PlanCard(name: bill.plan.definition.name, chip: "YOUR PLAN", price: Say.money(bill.forecast),
                                 note: "this month", traits: traits(bill.plan.definition), isChosen: isChosen(bill.plan.definition.id)) {
                            chosen = bill.plan.definition.id
                        }
                        ForEach(account.quotes, id: \.plan.id) { quote in
                            PlanCard(name: quote.plan.name, chip: quote.plan.stopsAtLimits ? "FREE" : "\(Say.money(quote.plan.subscription)) / mo",
                                     price: Say.money(quote.cost), note: "this month, if you'd been on it",
                                     traits: traits(quote.plan), isChosen: isChosen(quote.plan.id)) { chosen = quote.plan.id }
                        }
                    }
                    PlanDetail(account: account, bill: bill, chosen: chosen ?? bill.plan.definition.id)
                }
                InvoicesCard(account: account, bill: bill)
            } else {
                Text("Reading this month…").font(Pop.body(12)).foregroundStyle(Pop.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12).popCard()
            }
        }
    }

    private func isChosen(_ id: String) -> Bool { (chosen ?? account.plan.definition.id) == id }

    private func traits(_ plan: PlanDefinition) -> [String] {
        plan.stopsAtLimits ? ["stops at its limits", "past a limit, it fails until 00:00 UTC"]
                           : ["never stops", "past what's included, it charges"]
    }
}

/// *Free is enough* or *Free stopped you on 2 days*.
struct VerdictCard: View {
    let account: Account
    let bill: Bill

    var body: some View {
        let (head, rest, stopped) = words
        (Text(head).font(Pop.label(11.5)) + Text(" " + rest).font(Pop.body(11.5)))
            .foregroundStyle(Pop.ink).fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .popCard(stopped ? Pop.butterSoft : Color(red: 0.957, green: 1, blue: 0.973))
    }

    private var words: (String, String, Bool) {
        let plan = bill.plan.definition
        guard plan.stopsAtLimits else {
            return ("\(plan.name) never stops you.", "Past what it includes, it charges; the estimate above is this month's.", false)
        }
        switch bill.verdict {
        case .enough:
            return ("\(plan.name) is enough.", "No limit reached its stop this month. Upgrade when one would stop you.", false)
        case .stopped(let days, let limits):
            let names = limits.compactMap { account.definition(of: $0)?.name }.joined(separator: " and ")
            let dates = days.map { Say.day($0, format: "MMM d") }.joined(separator: ", ")
            var rest = "\(names) ran out on \(dates) until 00:00 UTC."
            if let paid = account.quotes.first(where: { !$0.plan.stopsAtLimits }) {
                rest += " On \(paid.plan.name) this month would cost \(Say.money(paid.cost)) and nothing would have stopped."
            }
            return ("\(plan.name) stopped you on \(days.count) day\(days.count == 1 ? "" : "s").", rest, true)
        }
    }
}

/// The chosen plan's month: each limit against a plan that stops, or the lines of one that charges.
struct PlanDetail: View {
    let account: Account
    let bill: Bill
    let chosen: String

    var body: some View {
        let isCurrent = chosen == bill.plan.definition.id
        let quote = account.quotes.first { $0.plan.id == chosen }
        let plan = isCurrent ? bill.plan.definition : quote?.plan
        VStack(spacing: 0) {
            if let plan {
                ListHeading(title: "This month on \(plan.name)",
                            note: isCurrent ? (plan.stopsAtLimits ? "your plan · stops instead of charging" : "your plan · est.") : "at this pace · est.")
                if plan.stopsAtLimits {
                    let days = isCurrent ? bill.days(on: bill.plan) : (quote?.days ?? [:])
                    ForEach(days.keys.sorted { $0.rawValue < $1.rawValue }, id: \.self) { id in
                        if let day = days[id] {
                            ListRow(label: account.definition(of: id)?.name ?? id.rawValue, note: dayNote(day),
                                    value: "\(day.stopped.count) day\(day.stopped.count == 1 ? "" : "s")",
                                    fraction: day.busiest.flatMap { $0.used.fraction(of: day.allowance) },
                                    tint: day.stopped.isEmpty ? Pop.mint : Pop.coral)
                        }
                    }
                    ListRow(label: "Total", note: "\(plan.name) never charges; past a limit, requests fail until 00:00 UTC",
                            value: Say.money(isCurrent ? bill.forecast : (quote?.cost ?? bill.forecast)))
                } else {
                    let lines = isCurrent ? bill.lines(on: bill.plan) : (quote?.lines ?? [])
                    ListRow(label: "Subscription", note: "includes everything below up to its amount", value: Say.money(plan.subscription))
                    ForEach(lines, id: \.limit) { line in
                        ListRow(label: account.definition(of: line.limit)?.name ?? line.limit.rawValue, note: lineNote(line),
                                value: Say.money(line.cost), fraction: line.used.fraction(of: line.included),
                                tint: line.cost.amount > 0 ? Pop.coral : Pop.mint)
                    }
                    ListRow(label: "Total", value: Say.money(isCurrent ? bill.forecast : (quote?.cost ?? bill.forecast)))
                    if !isCurrent, let url = quote?.upgradeURL {
                        VStack(alignment: .leading, spacing: 8) {
                            PopButton(title: "Upgrade on Cloudflare ↗", fill: Pop.mint) { NSWorkspace.shared.open(url) }
                            Text("Edge Meter only reads: Cloudflare takes the payment. After you upgrade, the next look here shows \(plan.name).")
                                .font(Pop.label(10)).foregroundStyle(Pop.muted).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                    }
                }
            }
        }
        .popCard()
    }

    private func dayNote(_ day: LimitDays) -> String {
        let allowance = "\(day.allowance.short) a day"
        if !day.stopped.isEmpty {
            return "\(allowance) · ran out on " + day.stopped.map { Say.day($0, format: "MMM d") }.joined(separator: " and ")
        }
        guard let busiest = day.busiest else { return "\(allowance) · nothing used yet" }
        return "\(allowance) · busiest day \(busiest.used.short) (\(Say.day(busiest.day, format: "MMM d")))"
    }

    private func lineNote(_ line: CostLine) -> String {
        let used = "~\(line.used.short) of \(line.included.short) included"
        guard line.cost.amount > 0 else { return used }
        let past = Quantity(line.used.value - line.included.value, line.used.unit).short
        return "\(used) · \(past) past it"
    }
}

struct InvoicesCard: View {
    let account: Account
    let bill: Bill

    var body: some View {
        VStack(spacing: 0) {
            ListHeading(title: "Invoices")
            if account.missing.contains(.billing) {
                Text("Invoices need an API token with Billing Read.").font(Pop.body(11)).foregroundStyle(Pop.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            } else if bill.invoices.isEmpty {
                Text("No invoices yet.").font(Pop.body(11)).foregroundStyle(Pop.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }
            ForEach(bill.invoices.prefix(6)) { invoice in
                ListRow(label: Say.day(invoice.at, format: "MMMM yyyy"), note: invoice.status, value: Say.money(invoice.amount))
            }
        }
        .popCard()
    }
}

/// *This month · est. $0.00 · On Workers Paid $5.00*.
struct MonthCard: View {
    let account: Account
    let bill: Bill
    let now: Date
    var big = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bill.issued == nil ? "THIS MONTH · EST." : "THIS MONTH · INVOICED").font(Pop.label(10)).tracking(0.6)
                    Text(Say.money(bill.issued?.amount ?? bill.estimate)).font(Pop.display(30))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if big {
                        Text("FORECAST · \(Say.day(bill.period.end.addingTimeInterval(-1), format: "MMM d").uppercased())").font(Pop.label(10)).tracking(0.6)
                        Text(Say.money(bill.forecast)).font(Pop.display(20))
                    } else if let quote = account.quotes.first {
                        Text("ON \(quote.plan.name.uppercased())").font(Pop.label(10)).tracking(0.6)
                        Text(Say.money(quote.cost)).font(Pop.display(20))
                    }
                }
            }
            Gauge(fraction: bill.elapsed(at: now), fill: Pop.mint, height: 16)
            Text(note).font(Pop.label(10.5)).foregroundStyle(Color(red: 0.122, green: 0.420, blue: 0.243))
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .popCard(Pop.butter)
    }

    private var note: String {
        let days = Int((bill.elapsed(at: now) * bill.period.length / 86_400).rounded(.up))
        let total = Int((bill.period.length / 86_400).rounded())
        if bill.estimate == bill.plan.definition.subscription {
            return "✓ \(bill.plan.definition.name) · day \(days) of \(total) · nothing past the allowances"
        }
        return "\(bill.plan.definition.name) · day \(days) of \(total) · Cloudflare's invoice replaces the estimate"
    }
}

struct PlanCard: View {
    let name: String
    let chip: String
    let price: String
    let note: String
    let traits: [String]
    let isChosen: Bool
    let tell: () -> Void

    var body: some View {
        Button(action: tell) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(name).font(Pop.label(12.5))
                    Spacer(minLength: 4)
                    Chip(text: chip, fill: chip == "YOUR PLAN" ? Pop.mint : Pop.sky)
                }
                Text(price).font(Pop.display(24)).padding(.top, 2)
                Text(note).font(Pop.label(10)).foregroundStyle(Pop.muted)
                ForEach(traits, id: \.self) { trait in
                    Text(trait).font(Pop.label(10)).foregroundStyle(Pop.muted).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
            .foregroundStyle(Pop.ink)
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .popCard(isChosen ? Pop.grapeSoft : Pop.paper, shadow: isChosen ? Pop.grape : Pop.ink)
        }
        .buttonStyle(.plain)
    }
}
