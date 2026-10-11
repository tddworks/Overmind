import Foundation
import Observation
import Measures
import Services
import Plans
import Limits
import Analytics
import Billing
import Alerts
import Diagnostics

/// THE ROOT: the Cloudflare account the token reads (CANONICAL §1). Views read it and tell
/// it what happened; every law it applies lives on the node that owns it.
@MainActor @Observable
public final class Account {
    public enum Phase: Sendable, Equatable {
        case notConnected
        case connecting
        /// The token answers for several accounts: *Account ▾*.
        case choosing([AccountSummary])
        case connected(AccountSummary)
        /// Cloudflare said no, and why: *Connect again*.
        case refused(Refusal)
    }

    /// Why Cloudflare said no: a wrong token (401) reads differently from a token that lacks a
    /// permission (403) (law 12).
    public enum Refusal: Sendable, Equatable {
        /// 401: the token is wrong, revoked or expired.
        case invalidToken
        /// 403 on the account list: the token works but can see no account.
        case cannotSeeAccount
        /// 403 on the usage query: the token lacks Account Analytics Read.
        case cannotReadAnalytics
    }

    public enum Freshness: Sendable, Equatable { case live, stale, refused, never }

    /// What the credential can't read: a reason on the part that needs it (law 12).
    public enum Permission: Sendable, Hashable { case billing }

    public private(set) var phase: Phase = .notConnected
    public private(set) var plan: Plan
    public let services: [ServiceDefinition]
    public private(set) var limits: [Limit] = []
    public private(set) var lastRead: Date?
    public private(set) var lastProblem: String?
    public private(set) var missing: Set<Permission> = []
    public private(set) var workers: [String] = []
    public private(set) var breakdowns: [String: [Breakdown]] = [:]
    public private(set) var deployments: [Deployment] = []
    public private(set) var bill: Bill?
    public private(set) var quotes: [Quote] = []
    public private(set) var alerts: Alerts
    public private(set) var isRefreshing = false

    /// How often the refresher reads; *stale* after two of these without a good read (law 17).
    public private(set) var interval: TimeInterval

    /// The read intervals the person can choose, in minutes.
    public static let intervals = [5, 10, 15, 30]

    /// Which Worker the tabs describe. Never a limit's reading (law 1).
    public var focus: Focus {
        didSet {
            guard focus != oldValue else { return }
            breakdowns = [:]
            deployments = []
            save()
        }
    }

    /// What the person chose in *Watching*, by service id; a service not here follows its file.
    private var choices: [String: Bool]

    let plans: [PlanDefinition]
    let analytics: any AnalyticsAPI
    let billing: any BillingAPI
    let vault: any TokenVault
    let settings: any SettingsStore
    let notifier: any Notifier
    private var breakdownsReadAt: [String: Date] = [:]
    /// When the plan was last read; it is read again once a day (law 18).
    private var planReadAt: Date?
    static let planEvery: TimeInterval = 86_400

    public init(services: [ServiceDefinition], plans: [PlanDefinition], analytics: any AnalyticsAPI, billing: any BillingAPI,
                vault: any TokenVault, settings: any SettingsStore, notifier: any Notifier) throws {
        self.services = services
        self.plans = plans
        self.analytics = analytics
        self.billing = billing
        self.vault = vault
        self.settings = settings
        self.notifier = notifier
        let saved = settings.load()
        focus = saved.focus
        interval = TimeInterval((Self.intervals.contains(saved.interval) ? saved.interval : 5) * 60)
        alerts = Alerts(settings: saved.alerts, sent: saved.sent)
        choices = saved.watch
        menuBarShows = saved.menuBar
        plan = Plan(try PlanCatalog.plan(forRatePlans: [], among: plans), renewsOn: nil)
        limits = Self.limits(watching, on: plan, keeping: [])
    }

    // MARK: Connecting

    /// After a launch: the saved account and token, if there are both.
    public func start(at now: Date) async {
        guard let saved = settings.load().account, vault.load() != nil else { return }
        await use(saved, at: now)
    }

    /// *Connect* with a pasted token (journey 1). Nothing is kept if Cloudflare refuses it.
    public func connect(token: String, at now: Date) async {
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        phase = .connecting
        do {
            try vault.save(token)
        } catch {
            lastProblem = "Couldn't keep the token in the Keychain"
            phase = .notConnected
            return
        }
        do {
            let accounts = try await billing.accounts()
            switch accounts.count {
            case 0:
                vault.delete()
                refuse(.cannotSeeAccount)
            case 1:
                await use(accounts[0], at: now)
            default:
                phase = .choosing(accounts)
            }
        } catch BillingError.refused {
            vault.delete()
            refuse(.invalidToken)
        } catch BillingError.forbidden {
            vault.delete()
            refuse(.cannotSeeAccount)
        } catch is TokenUnavailable {
            vault.delete()
            lastProblem = Self.keychainProblem
            phase = .notConnected
        } catch {
            vault.delete()
            lastProblem = "Couldn't reach Cloudflare"
            phase = .notConnected
        }
    }

    /// *Account ▾* (journey 2).
    public func choose(_ summary: AccountSummary, at now: Date) async {
        await use(summary, at: now)
    }

    /// Removes the token from the Keychain and forgets the account.
    public func disconnect() {
        vault.delete()
        phase = .notConnected
        lastRead = nil
        limits = Self.limits(watching, on: plan, keeping: [])
        breakdowns = [:]
        bill = nil
        var saved = settings.load()
        saved.account = nil
        settings.save(saved)
    }

    private func use(_ summary: AccountSummary, at now: Date) async {
        phase = .connected(summary)
        save()
        await readPlan(summary, at: now)
        workers = (try? await billing.scripts(account: summary.id)) ?? []
        await refresh(at: now)
    }

    /// The plan, from the account's subscriptions; Free when the token can't read them.
    private func readPlan(_ summary: AccountSummary, at now: Date) async {
        planReadAt = now
        do {
            let subscriptions = try await billing.subscriptions(account: summary.id)
            let ratePlans = subscriptions.map(\.ratePlan)
            let renewal = { (definition: PlanDefinition) in subscriptions.first { definition.matches.contains($0.ratePlan) }?.renewsOn }
            let definition = try PlanCatalog.plan(forRatePlans: ratePlans, among: plans)
            let addOns = PlanCatalog.addOns(forRatePlans: ratePlans, among: plans).map { Plan($0, renewsOn: renewal($0)) }
            plan = Plan(definition, renewsOn: renewal(definition), addOns: addOns)
        } catch {
            missing.insert(.billing)
        }
        limits = Self.limits(watching, on: plan, keeping: limits)
    }

    // MARK: Reading

    /// One read of every limit (TARGET §3.2). A failure changes freshness and nothing else.
    public func refresh(at now: Date) async {
        guard case .connected(let summary) = phase, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        if let planReadAt, now.timeIntervalSince(planReadAt) >= Self.planEvery { await readPlan(summary, at: now) }
        let reads = limits.map { LimitRead($0.definition, period: plan.period(for: $0.id, at: now)) }
        let planned = ReadPlan(account: summary.id).limits(reads, at: now)
        let started = Date()
        do {
            let usages = try planned.usages(from: try await analytics.read(planned.query))
            for index in limits.indices {
                if let usage = usages[limits[index].id] { limits[index].record(usage) }
            }
            lastRead = now
            lastProblem = nil
            AppLog.analytics.info("read \(usages.count) limits in \(Date().timeIntervalSince(started), format: .fixed(precision: 2))s")
        } catch AnalyticsError.refused {
            refuse(.invalidToken)
            return
        } catch AnalyticsError.forbidden {
            refuse(.cannotReadAnalytics)
            return
        } catch is TokenUnavailable {
            lastProblem = Self.keychainProblem
            AppLog.monitor.error("the token couldn't be read from the Keychain")
            return
        } catch AnalyticsError.rejected(let messages) {
            lastProblem = messages.first ?? "Cloudflare couldn't answer"
            return
        } catch {
            lastProblem = "Couldn't reach Cloudflare"
            AppLog.analytics.error("read failed")
            return
        }
        let warnings = alerts.check(limits, at: now)
        save()
        for warning in warnings { await notifier.post(warning) }
    }

    /// A service's tab (TARGET §3.3): its charts for the focus, and the focused Worker's
    /// deployments. Read again only when older than one refresh.
    public func open(_ serviceID: String, at now: Date) async {
        guard case .connected(let summary) = phase, let service = watching.first(where: { $0.id == serviceID }) else { return }
        if let readAt = breakdownsReadAt[serviceID], now.timeIntervalSince(readAt) < interval, breakdowns[serviceID] != nil { return }
        let planned = ReadPlan(account: summary.id).breakdowns(service, focus: focus, at: now)
        if let answer = try? await analytics.read(planned.query), let read = try? planned.breakdowns(from: answer) {
            breakdowns[serviceID] = read
            breakdownsReadAt[serviceID] = now
        }
        if focus.dimension == "scriptName", let script = focus.value {
            deployments = (try? await billing.deployments(account: summary.id, script: script)) ?? []
        }
    }

    /// *Bill* (TARGET §3.4): the billing month's use, priced by this plan and quoted on the
    /// others.
    public func openBill(at now: Date) async {
        guard case .connected(let summary) = phase else { return }
        // An upgrade made on Cloudflare shows here without a restart (law 18).
        await readPlan(summary, at: now)
        let month = Period.month(containing: now, renewsOn: plan.renewsOn)
        let definitions = watching.flatMap(\.limits).filter { definition in
            plans.contains { $0.price(for: definition.id) != nil }
        }
        let reads = definitions.map { LimitRead($0, period: Self.isKept($0) ? nil : month) }
        let planned = ReadPlan(account: summary.id).limits(reads, at: now)
        guard let usages = try? planned.usages(from: try await analytics.read(planned.query)) else { return }
        let monthToDate = usages.filter { !Self.isKept(usage: $0.value) }.mapValues(\.used)
        let kept = usages.filter { Self.isKept(usage: $0.value) }.mapValues(\.used)
        var invoices: [Invoice] = []
        do {
            invoices = try await billing.invoices(account: summary.id)
        } catch {
            missing.insert(.billing)
        }
        // Each day's use of every limit some plan allows per day: the days Free stops you (law 19).
        let dailyLimits = watching.flatMap(\.limits).filter { definition in
            plans.contains { if case .perDay = $0.allowance(for: definition.id) { true } else { false } }
        }
        var daily: [LimitID: [Date: Quantity]] = [:]
        if !dailyLimits.isEmpty {
            let plannedDays = ReadPlan(account: summary.id).daily(dailyLimits, over: month, at: now)
            daily = (try? plannedDays.days(from: try await analytics.read(plannedDays.query))) ?? [:]
        }
        let bill = Bill(plan: plan, monthToDate: monthToDate, kept: kept, invoices: invoices, daily: daily, at: now)
        self.bill = bill
        // Another Workers plan, with the same add-ons: R2 stays whatever Workers plan you pick (law 23).
        quotes = plans.filter { !$0.addOn && $0.id != plan.definition.id }.map { definition in
            let other = Plan(definition, renewsOn: nil, addOns: plan.addOns)
            return Quote(plan: definition, cost: bill.quote(on: other), lines: bill.lines(on: other),
                         days: bill.days(on: other), upgradeURL: definition.upgradeURL(account: summary.id))
        }
    }

    static let keychainProblem = "Couldn't read the token back from the Keychain"

    private func refuse(_ refusal: Refusal) {
        AppLog.monitor.error("Cloudflare refused: \(String(describing: refusal), privacy: .public)")
        phase = .refused(refusal)
    }

    static func isKept(_ definition: LimitDefinition) -> Bool {
        if case .max = definition.read { return true }
        return false
    }

    static func isKept(usage: Usage) -> Bool { usage.period == nil }

    /// *Read every 5 · 10 · 15 · 30 min* (law 17); any other choice is refused.
    public func setInterval(minutes: Int) {
        guard Self.intervals.contains(minutes) else { return }
        interval = TimeInterval(minutes * 60)
        save()
    }

    // MARK: Watching

    /// *Worker ☑ · D1 ☑ · KV ☐*: the services Overmind reads, in catalog order. One the person
    /// never chose for follows its file; never empty (law 21).
    public var watching: [ServiceDefinition] {
        let watched = services.filter { choices[$0.id] ?? $0.watchedByDefault }
        return watched.isEmpty ? Array(services.prefix(1)) : watched
    }

    public func isWatching(_ serviceID: String) -> Bool { watching.contains { $0.id == serviceID } }

    /// Whether the account's plans count any of this service: R2 needs R2 on the account
    /// (*not on this account's plans*). A service with no limits (AI Gateway) has nothing a plan
    /// could miss.
    public func isCounted(_ serviceID: String) -> Bool {
        guard let service = services.first(where: { $0.id == serviceID }) else { return false }
        return service.limits.isEmpty || service.limits.contains { plan.allowance(for: $0.id) != nil }
    }

    /// Whether *Watching* lets this switch go off: never the last one (law 21).
    public func canUnwatch(_ serviceID: String) -> Bool { isWatching(serviceID) && watching.count > 1 }

    /// Turns a service on, and reads it at once (law 21).
    public func watch(_ serviceID: String, at now: Date) async {
        guard services.contains(where: { $0.id == serviceID }), !isWatching(serviceID) else { return }
        choices[serviceID] = true
        limits = Self.limits(watching, on: plan, keeping: limits)
        save()
        await refresh(at: now)
    }

    /// Turns a service off: its limits, tab and charts go; the sent-warnings log stays. The last
    /// watched service stays on (law 21).
    public func unwatch(_ serviceID: String) {
        guard canUnwatch(serviceID) else { return }
        choices[serviceID] = false
        limits = Self.limits(watching, on: plan, keeping: limits)
        breakdowns[serviceID] = nil
        breakdownsReadAt[serviceID] = nil
        save()
    }

    /// What the Bill's estimate counts: *est.* or *est. · Worker only* (law 21).
    public var estimateCovers: Coverage {
        watching.count == services.count ? .everything : .only(watching.map(\.name))
    }

    // MARK: Alerts

    public func setLevel(_ level: Int, on: Bool) {
        if on { alerts.settings.levels.insert(level) } else { alerts.settings.levels.remove(level) }
        save()
    }

    public func setPace(_ on: Bool) {
        alerts.settings.pace = on
        save()
    }

    public func setNotify(_ on: Bool) {
        alerts.settings.isOn = on
        save()
    }

    // MARK: Derived

    public func limit(_ id: LimitID) -> Limit? { limits.first { $0.id == id } }

    /// A limit's definition, whether or not this plan counts it: its name on the Bill.
    public func definition(of limit: LimitID) -> LimitDefinition? {
        services.lazy.flatMap(\.limits).first { $0.id == limit }
    }

    /// The service a limit belongs to: its icon on a card.
    public func service(of limit: LimitID) -> ServiceDefinition? {
        services.first { $0.limits.contains { $0.id == limit } }
    }

    public func limits(of serviceID: String) -> [Limit] {
        let ids = Set(services.first { $0.id == serviceID }?.limits.map(\.id) ?? [])
        return limits.filter { ids.contains($0.id) }
    }

    /// The limit that runs out with the highest percent; a tie goes to the higher pace (law 8).
    public func closest(at now: Date) -> Limit? {
        limits.filter { $0.runsOut && $0.percent(at: now) != nil }.max { a, b in
            let (pa, pb) = (a.percent(at: now)!, b.percent(at: now)!)
            if pa != pb { return pa < pb }
            return (a.pace(at: now)?.atPeriodEnd ?? Percent(0)) < (b.pace(at: now)?.atPeriodEnd ?? Percent(0))
        }
    }

    /// *Menu bar shows: Closest limit · Icon only* (law 22).
    public private(set) var menuBarShows: MenuBarStyle

    public func setMenuBar(_ style: MenuBarStyle) {
        menuBarShows = style
        save()
    }

    /// `☁` before the first read; *D1 18%* coloured by the worst level; or, on *icon only* or
    /// when nothing on the plan runs out, the cloud and the worst level's mark (law 22).
    public func menuBar(at now: Date) -> MenuBarState {
        guard let worst = limits.compactMap({ $0.level(at: now) }).max() else { return .notReadYet }
        guard menuBarShows == .closestLimit, let closest = closest(at: now), let percent = closest.percent(at: now) else {
            return .iconOnly(worst)
        }
        return .closest(short: closest.definition.short, percent: percent, level: worst)
    }

    /// *LIVE* · *STALE* (law 11).
    public func freshness(at now: Date) -> Freshness {
        if case .refused = phase { return .refused }
        guard let lastRead else { return .never }
        return now.timeIntervalSince(lastRead) < 2 * interval ? .live : .stale
    }

    public var summary: AccountSummary? {
        if case .connected(let summary) = phase { return summary }
        return nil
    }

    /// The Cloudflare dashboard for this account (journey 18).
    public var dashboardURL: URL {
        URL(string: "https://dash.cloudflare.com/\(summary?.id ?? "")")!
    }

    // MARK: Helpers

    /// One limit per watched service's limit the plan has an allowance for, keeping readings.
    static func limits(_ services: [ServiceDefinition], on plan: Plan, keeping old: [Limit]) -> [Limit] {
        services.flatMap(\.limits).compactMap { definition in
            guard let allowance = plan.allowance(for: definition.id) else { return nil }
            var limit = Limit(definition, allowance: allowance)
            if let usage = old.first(where: { $0.id == definition.id && $0.allowance == allowance })?.usage { limit.record(usage) }
            return limit
        }
    }

    private func save() {
        settings.save(Settings(account: summary ?? settings.load().account, focus: focus, interval: Int(interval / 60),
                               alerts: alerts.settings, sent: alerts.sent, watch: choices,
                               menuBar: menuBarShows))
    }
}

/// Which services the Bill's estimate counts (law 21).
public enum Coverage: Sendable, Equatable {
    /// Every service: *est.*
    case everything
    /// Only these, by name: *est. · Worker only*.
    case only([String])
}

/// What the menu bar shows, one state at a time (law 22).
public enum MenuBarState: Sendable, Equatable {
    /// `☁`: nothing read yet.
    case notReadYet
    /// `☁`, `☁ ◐`, `☁ ⚠︎`: no limit named, by choice or because nothing on the plan runs out.
    case iconOnly(Level)
    /// `☁ D1 18%`, coloured by the worst level of any limit.
    case closest(short: String, percent: Percent, level: Level)
}

/// *Menu bar shows: Closest limit · Icon only* — the person's choice (law 22).
public enum MenuBarStyle: String, Sendable, Equatable, Codable, CaseIterable {
    case closestLimit, iconOnly
}

/// Another plan's price for this month's pace: *On Workers Paid $5.00*.
public struct Quote: Sendable, Equatable {
    public let plan: PlanDefinition
    public let cost: Money
    /// Where the cost comes from, one line per priced limit (law 20).
    public let lines: [CostLine]
    /// For a plan that stops at its limits: the days it would have stopped you (law 19).
    public let days: [LimitID: LimitDays]
    /// *Upgrade on Cloudflare ↗*; nil for a plan with no page to send you to.
    public let upgradeURL: URL?
}
