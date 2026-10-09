// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [:],
    // Mockable's IssueReporting needs its package name under Tuist (as in ClaudeBar).
    targetSettings: [
        "IssueReporting": ["SWIFT_PACKAGE_NAME": "xctest-dynamic-overlay"],
        "IssueReportingPackageSupport": ["SWIFT_PACKAGE_NAME": "xctest-dynamic-overlay"],
    ]
)
#endif

let package = Package(
    name: "EdgeMeter",
    dependencies: [
        // @Mockable ports, as in ClaudeBar: tests stub what lies outside the app (Chicago school).
        .package(url: "https://github.com/Kolos65/Mockable.git", from: "0.6.4"),
        // Updates (docs/features/updates): linked only by the App.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1"),
    ]
)
