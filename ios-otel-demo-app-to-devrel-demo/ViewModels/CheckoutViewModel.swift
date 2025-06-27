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
        let span = tracer.spanBuilder(spanName: "CheckoutViewModel.calculateShippingCost").startSpan()
        
        span.setAttribute(key: "shipping_address.city", value: AttributeValue.string(shippingInfo.city))
        span.setAttribute(key: "shipping_address.state", value: AttributeValue.string(shippingInfo.state))
        span.setAttribute(key: "shipping_address.country", value: AttributeValue.string(shippingInfo.country))
        span.setAttribute(key: "cart_items_count", value: AttributeValue.int(cartItems.count))
        span.setAttribute(key: "cart_subtotal", value: AttributeValue.double(subtotal))
        
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
            span.setAttribute(key: "shipping_cost", value: AttributeValue.double(shipping.doubleValue))
            
            HoneycombManager.shared.createEvent(name: "checkout.shipping_calculated")
                .addFields([
                    "shipping_cost": shipping.doubleValue,
                    "cart_items": cartItems.count,
                    "subtotal": subtotal
                ])
                .send()
            
        } catch {
            span.recordException(error)
            span.status = .error(description: error.localizedDescription)
            errorMessage = "Failed to calculate shipping: \(error.localizedDescription)"
            
            HoneycombManager.shared.createEvent(name: "checkout.shipping_calculation_failed")
                .addFields([
                    "error_message": error.localizedDescription,
                    "cart_items": cartItems.count
                ])
                .send()
        }
        
        isLoadingShipping = false
    }
    
    func placeOrder() async {
        guard canPlaceOrder else { return }
        
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "CheckoutViewModel.placeOrder").startSpan()
        
        span.setAttribute(key: "user_currency", value: AttributeValue.string("USD"))
        span.setAttribute(key: "cart_items_count", value: AttributeValue.int(cartItems.count))
        span.setAttribute(key: "order_total", value: AttributeValue.double(total))
        span.setAttribute(key: "shipping_cost", value: AttributeValue.double(shippingCost?.doubleValue ?? 0.0))
        span.setAttribute(key: "subtotal", value: AttributeValue.double(subtotal))
        
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
            span.status = .ok
            span.setAttribute(key: "order_number", value: AttributeValue.string(response.orderNumber))
            
            HoneycombManager.shared.createEvent(name: "checkout.order_placed")
                .addFields([
                    "order_number": response.orderNumber,
                    "order_total": total,
                    "cart_items": cartItems.count,
                    "shipping_cost": shippingCost?.doubleValue ?? 0.0
                ])
                .send()
            
        } catch {
            span.recordException(error)
            span.status = .error(description: error.localizedDescription)
            errorMessage = "Failed to place order: \(error.localizedDescription)"
            
            HoneycombManager.shared.createEvent(name: "checkout.order_failed")
                .addFields([
                    "error_message": error.localizedDescription,
                    "cart_items": cartItems.count,
                    "order_total": total
                ])
                .send()
        }
        
        isProcessingOrder = false
    }
    
    func clearOrder() {
        orderResult = nil
        errorMessage = nil
    }
}