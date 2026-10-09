import os

/// Where Edge Meter logs: OSLog, under one category per context. Log that something happened
/// and how long it took — never a token, a header, an account ID or an answer.
public enum AppLog {
    private static let subsystem = "com.tddworks.edgemeter"
    public static let monitor = Logger(subsystem: subsystem, category: "monitor")
    public static let analytics = Logger(subsystem: subsystem, category: "analytics")
    public static let billing = Logger(subsystem: subsystem, category: "billing")
    public static let alerts = Logger(subsystem: subsystem, category: "alerts")
}
