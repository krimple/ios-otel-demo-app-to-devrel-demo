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
    private let sessionManager = SessionManager.shared
    let cartItems: [CartItem] // Keep for backwards compatibility, but will be removed
    weak var cartViewModel: CartViewModel?
    
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
    
    init(checkoutService: CheckoutAPIService, cartItems: [CartItem], cartViewModel: CartViewModel? = nil) {
        self.checkoutService = checkoutService
        self.cartItems = cartItems
        self.cartViewModel = cartViewModel
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
            // Convert cart items to checkout items for shipping calculation
            let checkoutItems = cartItems.map { CheckoutItem(productId: $0.product.id, quantity: $0.quantity) }
            
            
            let shipping = try await checkoutService.getShippingCost(
                address: shippingInfo.toAddress(),
                items: checkoutItems
            )
            
            shippingCost = shipping
            span.status = .ok
            span.setAttribute(key: "app.shipping.cost", value: AttributeValue.double(shipping.doubleValue))
        } catch {
            errorMessage = "Failed to calculate shipping: \(error.localizedDescription)"
            
            // Only add stacktrace for non-cancelled errors
            if let urlError = error as? URLError, urlError.code != .cancelled {
                span.status = .error(description: error.localizedDescription)
                span.recordException(error)
            } else {
                // TODO - WTH is this??? AI, what did YOU do?
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
            let request = CheckoutRequest(
                userId: sessionManager.getSessionId(), // Use session ID as user ID for cart correlation
                userCurrency: "USD",
                address: shippingInfo.toAddress(),
                email: shippingInfo.email,
                creditCard: paymentInfo.toCreditCard()
                // items come from server-side cart, not passed in request
            )
            
            let response = try await checkoutService.placeOrder(request)
            orderResult = response
            errorMessage = nil  // Clear any previous error messages
            
            // Generate new session ID for next shopping session
            sessionManager.generateNewSessionId()
            
            // Clear cart on successful order (this will reload with new session)
            if let cartViewModel = cartViewModel {
                await cartViewModel.loadCart()
            }
            
            span.status = .ok
            span.setAttribute(key: "app.checkout.order.id", value: AttributeValue.string(response.orderId))
            span.setAttribute(key: "app.operation.type", value: AttributeValue.string("place_order"))
            
        } catch {
            errorMessage = "Failed to place order: \(error.localizedDescription)"
            
            // Only add stacktrace for non-cancelled errors
            if let urlError = error as? URLError, urlError.code != .cancelled {
                span.status = .error(description: error.localizedDescription)
                span.recordException(error)
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
