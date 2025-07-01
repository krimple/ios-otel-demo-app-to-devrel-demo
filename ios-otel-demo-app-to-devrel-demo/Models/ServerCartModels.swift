import Foundation

// MARK: - Server Cart Request Models
struct AddItemRequest: Codable {
    let userId: String
    let item: CartItemRequest
}

struct CartItemRequest: Codable {
    let productId: String
    let quantity: Int
}

struct GetCartRequest: Codable {
    let userId: String
}

struct EmptyCartRequest: Codable {
    let userId: String
}

// MARK: - Server Cart Response Models
struct ServerCart: Codable {
    let items: [ServerCartItem]
    
    var isEmpty: Bool {
        return items.isEmpty
    }
    
    var totalItems: Int {
        return items.reduce(0) { $0 + $1.quantity }
    }
}

struct ServerCartItem: Codable {
    let productId: String
    let quantity: Int
}

// MARK: - Conversion Extensions
extension ServerCartItem {
    func toCartItem(with product: Product) -> CartItem {
        return CartItem(product: product, quantity: quantity)
    }
}

extension CartItem {
    func toServerCartItem() -> ServerCartItem {
        return ServerCartItem(productId: product.id, quantity: quantity)
    }
}