import Foundation
import Honeycomb
import OpenTelemetryApi

enum CartError: LocalizedError {
    case serviceNotInitialized
    
    var errorDescription: String? {
        switch self {
        case .serviceNotInitialized:
            return "Cart service not initialized"
        }
    }
}

@MainActor
class CartViewModel: ObservableObject {
    static let shared = CartViewModel()
    
    @Published var items: [CartItem] = []
    @Published var totalCost: Double = 0.0
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cartAPIService: CartAPIService?
    private let sessionManager = SessionManager.shared
    
    private init() {
        // Private init for singleton
    }
    
    static func initializeShared(httpClient: HTTPClient, productService: ProductAPIService) {
        let cartAPIService = CartAPIService(httpClient: httpClient, productService: productService)
        shared.cartAPIService = cartAPIService
        
        // Load cart from server on initialization
        Task {
            await shared.loadCart()
        }
    }
    
    func addProduct(_ product: Product, quantity: Int = 1) {
        Task {
            await addProductAsync(product, quantity: quantity)
        }
    }
    
    private func addProductAsync(_ product: Product, quantity: Int = 1) async {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "addProductToCart").setActive(true).startSpan()
        
        // Add span attributes
        span.setAttribute(key: "app.product.id", value: AttributeValue.string(product.id))
        span.setAttribute(key: "app.product.name", value: AttributeValue.string(product.name))
        span.setAttribute(key: "app.cart.item.quantity", value: AttributeValue.int(quantity))
        span.setAttribute(key: "app.product.price.usd", value: AttributeValue.double(product.priceUsd.doubleValue))
        
        defer { span.end() }
        
        // Handle special crash/hang demo conditions
        let currentQuantity = getTotalQuantity(for: product.id)
        let newTotal = currentQuantity + quantity
        
        if product.id == "OLJCESPC7Z" && newTotal == 10 {
            // Trigger intentional crash for demo
            span.setAttribute(key: "app.demo.trigger", value: AttributeValue.string("crash"))
            triggerCrashDemo()
        } else if product.id == "OLJCESPC7Z" && newTotal == 9 {
            // Trigger intentional hang for demo
            span.setAttribute(key: "app.demo.trigger", value: AttributeValue.string("hang"))
            triggerHangDemo()
        } else if product.id == "OLJCESPC7Z" && newTotal == 8 {
            sendFakeMetrics()
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Add item to server cart
            guard let cartAPIService = cartAPIService else {
                throw CartError.serviceNotInitialized
            }
            
            let currentSessionId = sessionManager.getSessionId()
            
            try await cartAPIService.addItem(
                productId: product.id, 
                quantity: quantity, 
                userId: currentSessionId
            )
            
            // Reload cart from server to get updated state
            let cartItemsBefore = items.count
            
            // Add a small delay to allow server-side cart to be fully committed
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await loadCart()
            
            // Check if the cart is still empty after adding an item (indicates a problem)
            if items.isEmpty && cartItemsBefore == 0 {
                errorMessage = "Item was added to cart but not visible. This may be a temporary server issue. Please try refreshing the cart."
                span.setAttribute(key: "app.cart.discrepancy", value: AttributeValue.bool(true))
                span.addEvent(name: "cart_add_discrepancy", attributes: [
                    "expected_behavior": AttributeValue.string("cart_should_contain_added_item"),
                    "actual_behavior": AttributeValue.string("cart_appears_empty_after_add")
                ])
            } else {
                span.status = .ok
            }
            
            span.setAttribute(key: "app.cart.total.items", value: AttributeValue.int(items.count))
            span.setAttribute(key: "app.cart.total.cost", value: AttributeValue.double(totalCost))
            
        } catch {
            errorMessage = "Failed to add item to cart: \(error.localizedDescription)"
            // mark this as an error and report it to Honeycomb as a log record
            span.status = .error(description: error.localizedDescription)
            Honeycomb.log(error: error, thread: Thread.main)
        }
        
        isLoading = false
    }
    
    // Note: Individual item removal is not supported by the server cart API
    // This method is kept for compatibility but will show an error message
    // TODO REMOVE?
    func removeProduct(_ product: Product) {
        errorMessage = "Individual item removal is not supported. Use 'Clear Cart' to remove all items."
        
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "CartViewModel.removeProduct").setActive(true).startSpan()
        
        span.setAttribute(key: "app.product.id", value: AttributeValue.string(product.id))
        span.setAttribute(key: "app.product.name", value: AttributeValue.string(product.name))
        // TODO FIX
        // span.status = .error(description: errorMessage)

        span.end()
    }
    
    func clearCart() {
        Task {
            await clearCartAsync()
        }
    }
    
    private func clearCartAsync() async {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "CartViewModel.clearCart").setActive(true).startSpan()
        
        let previousItemCount = items.count
        span.setAttribute(key: "app.cart.previous.item.count", value: AttributeValue.int(previousItemCount))
        
        defer { span.end() }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Clear cart on server
            guard let cartAPIService = cartAPIService else {
                throw CartError.serviceNotInitialized
            }
            try await cartAPIService.emptyCart(userId: sessionManager.getSessionId())
            
            // Update local state
            items.removeAll()
            updateTotalCost()
            
            span.status = .ok
        } catch {
            errorMessage = "Failed to clear cart: \(error.localizedDescription)"
            span.recordException(error)
            span.status = .error(description: error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func loadCart() async {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "CartViewModel.loadCart").setActive(true).startSpan()
        
        defer { span.end() }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Load cart from server
            guard let cartAPIService = cartAPIService else {
                throw CartError.serviceNotInitialized
            }
            let cartItems = try await cartAPIService.getCart(userId: sessionManager.getSessionId())
            
            // Update local state
            items = cartItems
            updateTotalCost()
            
            span.status = .ok
            span.setAttribute(key: "app.cart.total.items", value: AttributeValue.int(items.count))
            span.setAttribute(key: "app.cart.total.cost", value: AttributeValue.double(totalCost))
            
        } catch {
            errorMessage = "Failed to load cart: \(error.localizedDescription)"
            // mark this as an error and report it to Honeycomb as a log record
            span.status = .error(description: error.localizedDescription)
            Honeycomb.log(error: error, thread: Thread.main)
        }
        
        isLoading = false
    }
    
    func refreshCart() {
        Task {
            await loadCart()
        }
    }
    
    private func getTotalQuantity(for productId: String) -> Int {
        return items.first(where: { $0.product.id == productId })?.quantity ?? 0
    }
    
    private func updateTotalCost() {
        totalCost = items.reduce(0) { total, item in
            total + (item.product.priceUsd.doubleValue * Double(item.quantity))
        }
    }
    
    private func triggerCrashDemo() {
        // Record the crash event before crashing
        HoneycombManager.shared.createEvent(name: "demo.crash_triggered")
            .addFields([
                "trigger": "10_explorascopes",
                "demo_type": "intentional_crash"
            ])
            .send()
        
        // Intentional crash for telemetry demonstration
        fatalError("Demo crash: Added 10 National Park Foundation Explorascopes")
    }
    
    private func triggerHangDemo() {
        // Record the hang event
        HoneycombManager.shared.createEvent(name: "demo.hang_triggered")
            .addFields([
                "trigger": "9_explorascopes",
                "demo_type": "intentional_hang",
                "duration_seconds": 10
            ])
            .send()
        
        // Intentional hang for demonstration
        // this is lame...
        // we need a more systemic slowdown.
        DispatchQueue.main.async {
            Thread.sleep(forTimeInterval: 10.0) // Block main thread
        }
    }
}
