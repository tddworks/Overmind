import Foundation

/// What a limit counts. The words a definition file uses for it are fixed here, so a file
/// can't invent a unit nobody draws.
public enum QuantityUnit: String, Sendable, Codable, CaseIterable {
    case rows, requests, milliseconds, bytes, count

    /// The word a definition file writes after the number, and how many base units it means:
    /// `GB` is a billion bytes, as Cloudflare prices storage.
    static let words: [String: (QuantityUnit, Double)] = [
        "rows": (.rows, 1), "requests": (.requests, 1), "count": (.count, 1),
        "ms": (.milliseconds, 1),
        "bytes": (.bytes, 1), "KB": (.bytes, 1e3), "MB": (.bytes, 1e6), "GB": (.bytes, 1e9),
    ]
}

/// An amount of something counted: *5M rows*, *10 ms*, *5 GB*.
public struct Quantity: Sendable, Equatable, Hashable, Codable {
    public let value: Double
    public let unit: QuantityUnit

    public init(_ value: Double, _ unit: QuantityUnit) {
        self.value = value
        self.unit = unit
    }

    /// Reads the way a definition file writes an amount: a number, an optional k/M/B, a unit.
    public init(parsing text: String) throws(MeasureError) {
        let parts = text.split(separator: " ").map(String.init)
        guard parts.count == 2, let (unit, scale) = QuantityUnit.words[parts[1]] else { throw .notAQuantity(text) }
        var number = parts[0]
        var multiplier = 1.0
        if let suffix = number.last, let factor = ["k": 1e3, "M": 1e6, "B": 1e9][String(suffix)] {
            multiplier = factor
            number.removeLast()
        }
        guard let value = Double(number) else { throw .notAQuantity(text) }
        self.init(value * multiplier * scale, unit)
    }

    /// How much of `whole` this is, as a fraction; nil when they count different things or
    /// the whole is nothing.
    public func fraction(of whole: Quantity) -> Double? {
        guard unit == whole.unit, whole.value > 0 else { return nil }
        return value / whole.value
    }
}

extension Quantity {
    /// The amount as a card prints it: *912k*, *3.75M*, *7.8 ms*, *41 MB*.
    public var short: String {
        switch unit {
        case .milliseconds:
            return "\(Self.trim(value, digits: value < 10 ? 1 : 0)) ms"
        case .bytes:
            for (size, word) in [(1e12, "TB"), (1e9, "GB"), (1e6, "MB"), (1e3, "KB")] where value >= size {
                return "\(Self.significant(value / size)) \(word)"
            }
            return "\(Int(value)) bytes"
        case .rows, .requests, .count:
            for (size, word) in [(1e9, "B"), (1e6, "M"), (1e3, "k")] where value >= size {
                return "\(Self.significant(value / size))\(word)"
            }
            return Self.trim(value, digits: 0)
        }
    }

    /// Three significant figures, without trailing zeros: 3.75, 9.81, 912.
    static func significant(_ value: Double) -> String {
        trim(value, digits: value < 10 ? 2 : value < 100 ? 1 : 0)
    }

    static func trim(_ value: Double, digits: Int) -> String {
        var text = String(format: "%.\(digits)f", value)
        if text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return text
    }
}

public enum MeasureError: Error, Equatable, Sendable {
    case notAQuantity(String)
    case notMoney(String)
}
