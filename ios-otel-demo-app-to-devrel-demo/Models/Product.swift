import Foundation

struct Product: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let picture: String
    let priceUsd: Money
    let categories: [String]
}

struct Money: Codable {
    let currencyCode: String
    let units: Int64
    let nanos: Int32
    
    var doubleValue: Double {
        return Double(units) + Double(nanos) / 1_000_000_000.0
    }
    
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: doubleValue)) ?? "$\(String(format: "%.2f", doubleValue))"
    }
}