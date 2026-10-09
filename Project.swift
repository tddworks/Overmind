import ProjectDescription

// One module per bounded context — docs/architecture/MODULAR_DESIGN.md.
// A module that isn't here yet is carved when its first test needs it.

let deployment: DeploymentTargets = .macOS("15.0")
let strict: SettingsDictionary = ["SWIFT_STRICT_CONCURRENCY": "complete"]

func module(_ name: String, dependencies: [TargetDependency] = [], resources: Bool = false) -> Target {
    .target(
        name: name,
        destinations: .macOS,
        product: .staticFramework,
        bundleId: "com.tddworks.edgemeter.\(name.lowercased())",
        deploymentTargets: deployment,
        sources: ["Modules/\(name)/Sources/**"],
        resources: resources ? ["Modules/\(name)/Resources/**"] : nil,
        dependencies: dependencies,
        settings: .settings(base: strict)
    )
}

func tests(_ name: String, dependencies: [TargetDependency] = []) -> Target {
    .target(
        name: "\(name)Tests",
        destinations: .macOS,
        product: .unitTests,
        bundleId: "com.tddworks.edgemeter.\(name.lowercased())-tests",
        deploymentTargets: deployment,
        sources: ["Modules/\(name)/Tests/**"],
        dependencies: [.target(name: name)] + dependencies
    )
}

let project = Project(
    name: "EdgeMeter",
    options: .options(defaultKnownRegions: ["en"], developmentRegion: "en"),
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "MACOSX_DEPLOYMENT_TARGET": "15.0",
        ],
        debug: ["SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG MOCKING"],
        release: ["SWIFT_ACTIVE_COMPILATION_CONDITIONS": "MOCKING"]
    ),
    targets: [
        // The app: views and the composition root. A menu bar app, no Dock icon.
        .target(
            name: "EdgeMeter",
            destinations: .macOS,
            product: .app,
            bundleId: "com.tddworks.edgemeter",
            deploymentTargets: deployment,
            infoPlist: .file(path: "Sources/App/Info.plist"),
            sources: ["Sources/App/**"],
            resources: ["Sources/App/Resources/**"],
            entitlements: .file(path: "Sources/App/entitlements.plist"),
            dependencies: [
                .target(name: "Monitor"), .target(name: "Storage"), .target(name: "Analytics"), .target(name: "Billing"),
                .target(name: "Alerts"), .target(name: "Limits"), .target(name: "Plans"), .target(name: "Services"),
                .target(name: "Measures"), .target(name: "Diagnostics"), .external(name: "Sparkle"),
            ],
            settings: .settings(
                base: strict.merging([
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "CODE_SIGN_IDENTITY": "-",
                    "ENABLE_HARDENED_RUNTIME": "YES",
                ]) { $1 },
                debug: [
                    // A debug copy never shares the installed app's bundle ID, so it never takes
                    // its Sparkle update (ClaudeBar issue #450).
                    "PRODUCT_BUNDLE_IDENTIFIER": "com.tddworks.edgemeter.debug",
                ]
            )
        ),
        // Measures — the shared kernel: Quantity, Money, Period, Percent. Imports nothing.
        module("Measures"),
        tests("Measures"),
        // Services — the Cloudflare products as data: what each counts and where. Pure.
        module("Services", dependencies: [.target(name: "Measures")], resources: true),
        tests("Services", dependencies: [.target(name: "Measures")]),
        // Plans — what each plan includes and what the rest costs, as data. Pure.
        module("Plans", dependencies: [.target(name: "Measures")], resources: true),
        tests("Plans", dependencies: [.target(name: "Measures")]),
        // Limits — Limit, Usage, Pace, Level: how close each limit is. Pure.
        module("Limits", dependencies: [.target(name: "Measures"), .target(name: "Services"), .target(name: "Plans")]),
        tests("Limits", dependencies: [.target(name: "Measures"), .target(name: "Services"), .target(name: "Plans")]),
        // Analytics — every limit as one GraphQL read, and the answer back as Usage; breakdowns.
        module("Analytics", dependencies: [.target(name: "Measures"), .target(name: "Services"), .target(name: "Plans"),
                                           .target(name: "Limits"), .target(name: "Diagnostics"), .external(name: "Mockable")]),
        // Billing — the plan, invoices, deployments, accounts over Cloudflare's REST API; the Bill.
        module("Billing", dependencies: [.target(name: "Measures"), .target(name: "Plans"), .target(name: "Diagnostics"),
                                         .external(name: "Mockable")]),
        tests("Billing", dependencies: [.target(name: "Measures"), .target(name: "Plans"), .external(name: "Mockable")]),
        // Alerts — which warnings are new (laws 9–10), and the port that shows them.
        module("Alerts", dependencies: [.target(name: "Measures"), .target(name: "Plans"), .target(name: "Services"),
                                        .target(name: "Limits"), .external(name: "Mockable")]),
        tests("Alerts", dependencies: [.target(name: "Measures"), .target(name: "Plans"), .target(name: "Services"),
                                       .target(name: "Limits"), .external(name: "Mockable")]),
        // Diagnostics — AppLog. Anything may import it.
        module("Diagnostics"),
        // Monitor — the root: Account, the refresh, the ports for the token and the settings.
        module("Monitor", dependencies: [.target(name: "Measures"), .target(name: "Services"), .target(name: "Plans"),
                                         .target(name: "Limits"), .target(name: "Analytics"), .target(name: "Billing"),
                                         .target(name: "Alerts"), .target(name: "Diagnostics"), .external(name: "Mockable")]),
        tests("Monitor", dependencies: [.target(name: "Measures"), .target(name: "Services"), .target(name: "Plans"),
                                        .target(name: "Limits"), .target(name: "Analytics"), .target(name: "Billing"),
                                        .target(name: "Alerts"), .external(name: "Mockable")]),
        // Storage — the Keychain and settings.json; implements Monitor's ports.
        module("Storage", dependencies: [.target(name: "Monitor"), .target(name: "Analytics"), .target(name: "Alerts"),
                                         .target(name: "Billing")]),
        tests("Storage", dependencies: [.target(name: "Monitor"), .target(name: "Analytics"), .target(name: "Alerts"),
                                        .target(name: "Billing")]),
        tests("Analytics", dependencies: [.target(name: "Measures"), .target(name: "Services"), .target(name: "Limits"),
                                          .external(name: "Mockable")]),
    ]
)
