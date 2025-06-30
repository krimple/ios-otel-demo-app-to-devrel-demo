import Foundation
import Honeycomb
import OpenTelemetryApi

@MainActor
class CartViewModel: ObservableObject {
    @Published var items: [CartItem] = []
    @Published var totalCost: Double = 0.0
    
    func addProduct(_ product: Product, quantity: Int = 1) {
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
        }
        
        // Normal cart logic
        if let existingIndex = items.firstIndex(where: { $0.product.id == product.id }) {
            items[existingIndex].quantity += quantity
        } else {
            items.append(CartItem(product: product, quantity: quantity))
        }
        
        updateTotalCost()
        span.status = .ok
        span.setAttribute(key: "app.cart.total.items", value: AttributeValue.int(items.count))
        span.setAttribute(key: "app.cart.total.cost", value: AttributeValue.double(totalCost))
        span.setAttribute(key: "app.operation.type", value: AttributeValue.string("add_product"))
        span.setAttribute(key: "app.operation.status", value: AttributeValue.string("success"))
    }
    
    func removeProduct(_ product: Product) {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "CartViewModel.removeProduct").setActive(true).startSpan()
        
        span.setAttribute(key: "app.product.id", value: AttributeValue.string(product.id))
        span.setAttribute(key: "app.product.name", value: AttributeValue.string(product.name))
        
        defer { span.end() }
        
        items.removeAll { $0.product.id == product.id }
        updateTotalCost()
        span.status = .ok
        span.setAttribute(key: "app.cart.total.items", value: AttributeValue.int(items.count))
        span.setAttribute(key: "app.cart.total.cost", value: AttributeValue.double(totalCost))
        span.setAttribute(key: "app.operation.type", value: AttributeValue.string("remove_product"))
        span.setAttribute(key: "app.operation.status", value: AttributeValue.string("success"))
    }
    
    func clearCart() {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "CartViewModel.clearCart").setActive(true).startSpan()
        
        let previousItemCount = items.count
        span.setAttribute(key: "app.cart.previous.item.count", value: AttributeValue.int(previousItemCount))
        
        defer { span.end() }
        
        items.removeAll()
        updateTotalCost()
        span.status = .ok
        span.setAttribute(key: "app.operation.type", value: AttributeValue.string("clear_cart"))
        span.setAttribute(key: "app.operation.status", value: AttributeValue.string("success"))
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
        DispatchQueue.main.async {
            Thread.sleep(forTimeInterval: 10.0) // Block main thread
        }
    }
}
