import Foundation

struct CheckoutRequest: Codable {
    let userId: String
    let userCurrency: String
    let address: Address
    let email: String
    let creditCard: CreditCard
    let items: [CheckoutItem]
}

struct CheckoutItem: Codable {
    let productId: String
    let quantity: Int
}

struct CheckoutResponse: Codable {
    let orderId: String
    let shippingTrackingId: String
    let shippingCost: Money
    let shippingAddress: Address
    let items: [OrderItem]
    
    // Backward compatibility property
    var orderNumber: String {
        return orderId
    }
    
    // Computed property for total (sum shipping + items)
    var total: Money {
        let itemsTotal = items.reduce(0.0) { $0 + $1.cost.doubleValue }
        let totalAmount = itemsTotal + shippingCost.doubleValue
        
        return Money(
            currencyCode: shippingCost.currencyCode,
            units: Int64(totalAmount),
            nanos: Int32((totalAmount - Double(Int64(totalAmount))) * 1_000_000_000)
        )
    }
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
    var id = UUID()
    let product: Product
    var quantity: Int
    
    var totalPrice: Double {
        return product.priceUsd.doubleValue * Double(quantity)
    }
}

// MARK: - Form Data Models
struct ShippingInfo {
    var email: String = "telescope.shopper@stargazer.example"
    var streetAddress: String = "1234 Observatory Way"
    var city: String = "Palo Alto"
    var state: String = "CA"
    var zipCode: String = "94301"
    var country: String = "USA"
    
    var isComplete: Bool {
        return !email.isEmpty && !streetAddress.isEmpty && !city.isEmpty && 
               !state.isEmpty && !zipCode.isEmpty && !country.isEmpty
    }
    
    func toAddress() -> Address {
        return Address(
            streetAddress: streetAddress,
            city: city,
            state: state,
            country: country,
            zipCode: zipCode
        )
    }
}

struct PaymentInfo {
    var creditCardNumber: String = "5555555555554444"  // Test MasterCard number
    var creditCardCvv: String = "123"
    var creditCardExpirationMonth: Int = 12
    var creditCardExpirationYear: Int = Calendar.current.component(.year, from: Date()) + 2
    
    var isComplete: Bool {
        return !creditCardNumber.isEmpty && !creditCardCvv.isEmpty &&
               creditCardExpirationMonth >= 1 && creditCardExpirationMonth <= 12 &&
               creditCardExpirationYear >= Calendar.current.component(.year, from: Date())
    }
    
    func toCreditCard() -> CreditCard {
        return CreditCard(
            creditCardNumber: creditCardNumber,
            creditCardCvv: creditCardCvv,
            creditCardExpirationYear: creditCardExpirationYear,
            creditCardExpirationMonth: creditCardExpirationMonth
        )
    }
}

