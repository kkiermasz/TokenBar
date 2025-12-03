import Foundation

enum CurrencyFormatter {
    static func usd(from decimal: Decimal) -> String {
        decimal.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }
}
