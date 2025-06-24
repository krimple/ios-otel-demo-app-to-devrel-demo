import Foundation

struct CheckoutRequest: Codable {
    let userId: String
    let userCurrency: String
    let address: Address
    let email: String
    let creditCard: CreditCard
}

struct CheckoutResponse: Codable {
    let orderNumber: String
    let shippingCost: Money
    let shippingAddress: Address
    let items: [OrderItem]
    let total: Money
}

struct OrderItem: Codable {
    let item: Product
    let cost: Money
}

struct Address: Codable {
    let streetAddress: String
    let city: String
    let state: String
    let country: String
    let zipCode: String
}

struct CreditCard: Codable {
    let creditCardNumber: String
    let creditCardCvv: String
    let creditCardExpirationYear: Int
    let creditCardExpirationMonth: Int
}

struct CartItem: Identifiable, Codable {
    let id = UUID()
    let product: Product
    var quantity: Int
    
    var totalPrice: Double {
        return product.priceUsd.doubleValue * Double(quantity)
    }
}