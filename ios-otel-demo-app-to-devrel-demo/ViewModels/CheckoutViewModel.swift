import Foundation
import Honeycomb
import OpenTelemetryApi

@MainActor
class CheckoutViewModel: ObservableObject {
    @Published var shippingInfo = ShippingInfo()
    @Published var paymentInfo = PaymentInfo()
    @Published var shippingCost: Money?
    @Published var isLoadingShipping = false
    @Published var isProcessingOrder = false
    @Published var orderResult: CheckoutResponse?
    @Published var errorMessage: String?
    
    private let checkoutService: CheckoutAPIService
    let cartItems: [CartItem]
    
    var subtotal: Double {
        cartItems.reduce(0) { $0 + $1.totalPrice }
    }
    
    var total: Double {
        let shipping = shippingCost?.doubleValue ?? 0.0
        return subtotal + shipping
    }
    
    var canProceedToPayment: Bool {
        shippingInfo.isComplete && shippingCost != nil
    }
    
    var canPlaceOrder: Bool {
        shippingInfo.isComplete && paymentInfo.isComplete && !isProcessingOrder
    }
    
    init(checkoutService: CheckoutAPIService, cartItems: [CartItem]) {
        self.checkoutService = checkoutService
        self.cartItems = cartItems
    }
    
    func calculateShippingCost() async {
        guard shippingInfo.isComplete else { return }
        
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "calculateShippingCost").setActive(true).startSpan()
        
        span.setAttribute(key: "app.shipping.address.city", value: AttributeValue.string(shippingInfo.city))
        span.setAttribute(key: "app.shipping.address.state", value: AttributeValue.string(shippingInfo.state))
        span.setAttribute(key: "app.shipping.address.country", value: AttributeValue.string(shippingInfo.country))
        span.setAttribute(key: "app.cart.items.count", value: AttributeValue.int(cartItems.count))
        span.setAttribute(key: "app.cart.subtotal", value: AttributeValue.double(subtotal))
        
        defer { span.end() }
        
        isLoadingShipping = true
        errorMessage = nil
        
        do {
            let checkoutItems = cartItems.map { CheckoutItem(productId: $0.product.id, quantity: $0.quantity) }
            let shipping = try await checkoutService.getShippingCost(
                address: shippingInfo.toAddress(),
                items: checkoutItems
            )
            
            shippingCost = shipping
            span.status = .ok
            span.setAttribute(key: "app.shipping.cost", value: AttributeValue.double(shipping.doubleValue))
            span.setAttribute(key: "app.operation.status", value: AttributeValue.string("success"))
            span.setAttribute(key: "app.operation.type", value: AttributeValue.string("calculate_shipping"))
            
        } catch {
            errorMessage = "Failed to calculate shipping: \(error.localizedDescription)"
            
            // Only add stacktrace for non-cancelled errors
            if let urlError = error as? URLError, urlError.code != .cancelled {
                span.recordException(error)
                span.status = .error(description: error.localizedDescription)
                span.setAttribute(key: "app.operation.status", value: AttributeValue.string("failed"))
                span.setAttribute(key: "app.operation.type", value: AttributeValue.string("calculate_shipping"))
                span.setAttribute(key: "exception.stacktrace", value: AttributeValue.string(Thread.callStackSymbols.joined(separator: "\n")))
            } else {
                span.status = .ok
                span.setAttribute(key: "app.http.timeout", value: AttributeValue.bool(true))
            }
        }
        
        isLoadingShipping = false
    }
    
    func placeOrder() async {
        guard canPlaceOrder else { return }
        
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "placeOrder").setActive(true).startSpan()
        
        span.setAttribute(key: "app.user.currency", value: AttributeValue.string("USD"))
        span.setAttribute(key: "app.cart.items.count", value: AttributeValue.int(cartItems.count))
        span.setAttribute(key: "app.checkout.order.total", value: AttributeValue.double(total))
        span.setAttribute(key: "app.checkout.shipping.cost", value: AttributeValue.double(shippingCost?.doubleValue ?? 0.0))
        span.setAttribute(key: "app.checkout.subtotal", value: AttributeValue.double(subtotal))
        
        defer { span.end() }
        
        isProcessingOrder = true
        errorMessage = nil
        
        do {
            let checkoutItems = cartItems.map { CheckoutItem(productId: $0.product.id, quantity: $0.quantity) }
            let request = CheckoutRequest(
                userId: "demo-user-\(UUID().uuidString)",
                userCurrency: "USD",
                address: shippingInfo.toAddress(),
                email: shippingInfo.email,
                creditCard: paymentInfo.toCreditCard(),
                items: checkoutItems
            )
            
            let response = try await checkoutService.placeOrder(request)
            orderResult = response
            errorMessage = nil  // Clear any previous error messages
            print("✅ Order placed successfully! Order ID: \(response.orderId)")
            span.status = .ok
            span.setAttribute(key: "app.checkout.order.id", value: AttributeValue.string(response.orderId))
            span.setAttribute(key: "app.operation.status", value: AttributeValue.string("success"))
            span.setAttribute(key: "app.operation.type", value: AttributeValue.string("place_order"))
            
        } catch {
            errorMessage = "Failed to place order: \(error.localizedDescription)"
            
            // Only add stacktrace for non-cancelled errors
            if let urlError = error as? URLError, urlError.code != .cancelled {
                span.recordException(error)
                span.status = .error(description: error.localizedDescription)
                span.setAttribute(key: "app.operation.status", value: AttributeValue.string("failed"))
                span.setAttribute(key: "app.operation.type", value: AttributeValue.string("place_order"))
                span.setAttribute(key: "exception.stacktrace", value: AttributeValue.string(Thread.callStackSymbols.joined(separator: "\n")))
            } else {
                span.status = .ok
                span.setAttribute(key: "app.http.timeout", value: AttributeValue.bool(true))
            }
        }
        
        isProcessingOrder = false
    }
    
    func clearOrder() {
        orderResult = nil
        errorMessage = nil
    }
}
