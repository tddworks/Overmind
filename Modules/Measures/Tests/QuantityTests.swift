import Foundation
import Testing
@testable import Measures

@Suite
struct QuantityTests {
    @Test func `should read 5M rows as five million rows`() throws {
        #expect(try Quantity(parsing: "5M rows") == Quantity(5_000_000, .rows))
    }

    @Test func `should read 100k requests as a hundred thousand requests`() throws {
        #expect(try Quantity(parsing: "100k requests") == Quantity(100_000, .requests))
    }

    @Test func `should read 25B rows as twenty-five billion rows`() throws {
        #expect(try Quantity(parsing: "25B rows") == Quantity(25_000_000_000, .rows))
    }

    @Test func `should read 5 GB as five billion bytes`() throws {
        #expect(try Quantity(parsing: "5 GB") == Quantity(5_000_000_000, .bytes))
    }

    @Test func `should read 10 ms as ten milliseconds`() throws {
        #expect(try Quantity(parsing: "10 ms") == Quantity(10, .milliseconds))
    }

    @Test func `should refuse an amount whose unit nobody counts`() {
        #expect(throws: MeasureError.self) { try Quantity(parsing: "5M bananas") }
    }

    @Test func `should say how many times one quantity fits in another of the same unit`() {
        #expect(Quantity(912_000, .rows).fraction(of: Quantity(5_000_000, .rows)) == 0.1824)
    }

    @Test func `should not compare quantities that count different things`() {
        #expect(Quantity(1, .rows).fraction(of: Quantity(1, .requests)) == nil)
    }
}

@Suite
struct MoneyTests {
    @Test func `should read 0.001 USD exactly, without floating-point drift`() throws {
        #expect(try Money(parsing: "0.001 USD") == Money(Decimal(string: "0.001")!, "USD"))
    }

    @Test func `should add two amounts in the same currency`() {
        #expect(Money(5, "USD") + Money(Decimal(string: "0.30")!, "USD") == Money(Decimal(string: "5.30")!, "USD"))
    }
}

@Suite
struct PercentTests {
    @Test func `should round 18.24% to 18% for the screen`() {
        #expect(Percent(fraction: 0.1824).rounded == 18)
    }
}

@Suite
struct ShortQuantityTests {
    @Test(arguments: [
        (Quantity(912_000, .rows), "912k"), (Quantity(3_750_000, .rows), "3.75M"), (Quantity(5_000_000, .rows), "5M"),
        (Quantity(25e9, .rows), "25B"), (Quantity(830, .requests), "830"), (Quantity(9_814, .requests), "9.81k"),
        (Quantity(7.84, .milliseconds), "7.8 ms"), (Quantity(41e6, .bytes), "41 MB"), (Quantity(5e9, .bytes), "5 GB"),
        (Quantity(512_000, .bytes), "512 KB"),
    ])
    func `should print an amount the way a card does`(quantity: Quantity, text: String) {
        #expect(quantity.short == text)
    }
}
