import Foundation

/// A chart or list on a service's tab, read for the focus.
public struct Breakdown: Sendable, Equatable, Identifiable {
    public let title: String
    public let content: Content

    public var id: String { title }

    public enum Content: Sendable, Equatable {
        case bars([Bar])
        case rows([Row])
    }

    public init(title: String, content: Content) {
        self.title = title
        self.content = content
    }
}

public struct Bar: Sendable, Equatable {
    public let at: Date
    public let value: Double

    public init(at: Date, value: Double) {
        self.at = at
        self.value = value
    }
}

public struct Row: Sendable, Equatable {
    public let label: String
    public let value: Double

    public init(label: String, value: Double) {
        self.label = label
        self.value = value
    }
}
