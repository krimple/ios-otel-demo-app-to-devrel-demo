import Foundation
import Honeycomb
import OpenTelemetryApi

class CartAPIService: ObservableObject {
    private let httpClient: HTTPClient
    private let productService: ProductAPIService
    
    init(httpClient: HTTPClient, productService: ProductAPIService) {
        self.httpClient = httpClient
        self.productService = productService
    }
    
    func addItem(productId: String, quantity: Int = 1, userId: String) async throws {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "CartAPIService.addItem").setActive(true).startSpan()
        
        span.setAttribute(key: "app.product.id", value: AttributeValue.string(productId))
        span.setAttribute(key: "app.cart.item.quantity", value: AttributeValue.int(quantity))
        span.setAttribute(key: "app.user.session_id", value: AttributeValue.string(userId))
        
        defer { span.end() }
        
        let request = AddItemRequest(
            userId: userId,
            item: CartItemRequest(productId: productId, quantity: quantity)
        )
        
        let requestData = try JSONEncoder().encode(request)
        
        do {
            print("🛒 CartAPIService.addItem - Posting to /cart for userId: \(userId)")
            let _: EmptyResponse = try await httpClient.request(
                endpoint: "/cart",
                method: .POST,
                body: requestData,
                queryParameters: ["sessionId": userId],
                spanName: "CartAPIService.addItem"
            )
            
            print("✅ CartAPIService.addItem - Successfully added item for userId: \(userId)")
            span.status = .ok
            span.setAttribute(key: "app.operation.status", value: AttributeValue.string("success"))
            span.setAttribute(key: "app.operation.type", value: AttributeValue.string("add_cart_item"))
            
        } catch {
            print("❌ CartAPIService.addItem - Failed for userId: \(userId), error: \(error)")
            span.recordException(error)
            span.status = .error(description: error.localizedDescription)
            span.setAttribute(key: "app.operation.status", value: AttributeValue.string("failed"))
            span.setAttribute(key: "app.operation.type", value: AttributeValue.string("add_cart_item"))
            throw error
        }
    }
    
    func getCart(userId: String) async throws -> [CartItem] {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "CartAPIService.getCart").setActive(true).startSpan()
        
        span.setAttribute(key: "app.user.session_id", value: AttributeValue.string(userId))
        
        defer { span.end() }
        
        do {
            print("🛒 CartAPIService.getCart - Fetching cart from /cart?sessionId=\(userId)")
            let serverCart: ServerCart = try await httpClient.request(
                endpoint: "/cart",
                method: .GET,
                queryParameters: [
                    "sessionId": userId,
                    "currencyCode": "USD"
                ],
                spanName: "CartAPIService.getCart"
            )
            print("✅ CartAPIService.getCart - Found cart with \(serverCart.items.count) items")
            
            // Convert server cart items to local cart items by fetching product details
            var cartItems: [CartItem] = []
            
            for serverItem in serverCart.items {
                do {
                    let product = try await productService.fetchProduct(id: serverItem.productId)
                    let cartItem = CartItem(product: product, quantity: serverItem.quantity)
                    cartItems.append(cartItem)
                } catch {
                    // Log error but continue with other items
                    span.addEvent(name: "failed_to_fetch_product", attributes: [
                        "product_id": AttributeValue.string(serverItem.productId),
                        "error": AttributeValue.string(error.localizedDescription)
                    ])
                }
            }
            
            span.status = .ok
            span.setAttribute(key: "app.cart.items.count", value: AttributeValue.int(cartItems.count))
            span.setAttribute(key: "app.cart.total.quantity", value: AttributeValue.int(cartItems.reduce(0) { $0 + $1.quantity }))
            span.setAttribute(key: "app.operation.status", value: AttributeValue.string("success"))
            span.setAttribute(key: "app.operation.type", value: AttributeValue.string("get_cart"))
            
            return cartItems
            
        } catch {
            // Handle 404 case - cart doesn't exist yet, return empty cart
            if let nsError = error as NSError?, nsError.code == 404 {
                print("⚠️ CartAPIService.getCart - Cart not found (404) for userId: \(userId), returning empty cart")
                span.status = .ok
                span.setAttribute(key: "app.cart.items.count", value: AttributeValue.int(0))
                span.setAttribute(key: "app.cart.total.quantity", value: AttributeValue.int(0))
                span.setAttribute(key: "app.operation.status", value: AttributeValue.string("success"))
                span.setAttribute(key: "app.operation.type", value: AttributeValue.string("get_cart"))
                span.setAttribute(key: "app.cart.status", value: AttributeValue.string("empty_new_session"))
                
                return [] // Return empty cart
            }
            
            print("❌ CartAPIService.getCart - Failed for userId: \(userId), error: \(error)")
            span.recordException(error)
            span.status = .error(description: error.localizedDescription)
            span.setAttribute(key: "app.operation.status", value: AttributeValue.string("failed"))
            span.setAttribute(key: "app.operation.type", value: AttributeValue.string("get_cart"))
            throw error
        }
    }
    
    func emptyCart(userId: String) async throws {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "CartAPIService.emptyCart").setActive(true).startSpan()
        
        span.setAttribute(key: "app.user.session_id", value: AttributeValue.string(userId))
        
        defer { span.end() }
        
        do {
            let _: EmptyResponse = try await httpClient.request(
                endpoint: "/cart",
                method: .DELETE,
                queryParameters: ["sessionId": userId],
                spanName: "CartAPIService.emptyCart"
            )
            
            span.status = .ok
            span.setAttribute(key: "app.operation.status", value: AttributeValue.string("success"))
            span.setAttribute(key: "app.operation.type", value: AttributeValue.string("empty_cart"))
            
        } catch {
            span.recordException(error)
            span.status = .error(description: error.localizedDescription)
            span.setAttribute(key: "app.operation.status", value: AttributeValue.string("failed"))
            span.setAttribute(key: "app.operation.type", value: AttributeValue.string("empty_cart"))
            throw error
        }
    }
}

// Empty response for endpoints that return no content
struct EmptyResponse: Codable {
}