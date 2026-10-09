import SwiftUI
import AppKit
import Measures
import Plans
import Billing
import Monitor

/// *Bill*: the month so far, its forecast, the other plans at this pace, and invoices.
struct BillView: View {
    let account: Account
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let bill = account.bill {
                MonthCard(account: account, bill: bill, now: now, big: true)
                SectionHeading(text: "The plans at this month's pace")
                HStack(alignment: .top, spacing: 10) {
                    PlanCard(name: bill.plan.definition.name, price: Say.money(bill.forecast), note: "your plan", isCurrent: true,
                             subscription: bill.plan.definition.subscription)
                    ForEach(account.quotes, id: \.plan.id) { quote in
                        PlanCard(name: quote.plan.name, price: Say.money(quote.cost), note: "est. this month", isCurrent: false,
                                 subscription: quote.plan.subscription)
                    }
                }
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
            } else {
                Text("Reading this month…").font(Pop.body(12)).foregroundStyle(Pop.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12).popCard()
            }
        }
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
    let price: String
    let note: String
    let isCurrent: Bool
    let subscription: Money

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(Pop.label(12.5))
                Spacer()
                Chip(text: isCurrent ? "NOW" : Say.money(subscription), fill: isCurrent ? Pop.mint : Pop.sky)
            }
            Text(price).font(Pop.display(24))
            Text(note).font(Pop.label(10)).foregroundStyle(Pop.muted)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .popCard(isCurrent ? Pop.grapeSoft : Pop.paper, shadow: isCurrent ? Pop.grape : Pop.ink)
    }
}
