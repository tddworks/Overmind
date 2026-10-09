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
            infoPlist: .extendingDefault(with: [
                "LSUIElement": true,
                "CFBundleDisplayName": "Edge Meter",
                "CFBundleShortVersionString": "0.1.0",
            ]),
            sources: ["Sources/App/**"],
            dependencies: [],
            settings: .settings(base: strict)
        ),
        // The modules land slice by slice (docs/status.md). Each is one line here:
        // module("Measures"), tests("Measures"), …
    ]
)
