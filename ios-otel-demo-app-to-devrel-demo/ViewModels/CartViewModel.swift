import Foundation
import Honeycomb
import OpenTelemetryApi

@MainActor
class CartViewModel: ObservableObject {
    @Published var items: [CartItem] = []
    @Published var totalCost: Double = 0.0
    
    func addProduct(_ product: Product, quantity: Int = 1) {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "CartViewModel.addProduct").startSpan()
        
        // Add span attributes
        span.setAttribute(key: "product_id", value: AttributeValue.string(product.id))
        span.setAttribute(key: "product_name", value: AttributeValue.string(product.name))
        span.setAttribute(key: "quantity", value: AttributeValue.int(quantity))
        span.setAttribute(key: "price_usd", value: AttributeValue.double(product.priceUsd.doubleValue))
        
        defer { span.end() }
        
        // Handle special crash/hang demo conditions
        let currentQuantity = getTotalQuantity(for: product.id)
        let newTotal = currentQuantity + quantity
        
        if product.id == "OLJCESPC7Z" && newTotal == 10 {
            // Trigger intentional crash for demo
            span.setAttribute(key: "demo_trigger", value: AttributeValue.string("crash"))
            triggerCrashDemo()
        } else if product.id == "OLJCESPC7Z" && newTotal == 9 {
            // Trigger intentional hang for demo
            span.setAttribute(key: "demo_trigger", value: AttributeValue.string("hang"))
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
        
        // Record product added event
        HoneycombManager.shared.createEvent(name: "cart.product_added")
            .addFields([
                "product_id": product.id,
                "product_name": product.name,
                "quantity": quantity,
                "cart_total_items": items.count,
                "cart_total_cost": totalCost
            ])
            .send()
    }
    
    func removeProduct(_ product: Product) {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "CartViewModel.removeProduct").startSpan()
        
        span.setAttribute(key: "product_id", value: AttributeValue.string(product.id))
        span.setAttribute(key: "product_name", value: AttributeValue.string(product.name))
        
        defer { span.end() }
        
        items.removeAll { $0.product.id == product.id }
        updateTotalCost()
        span.status = .ok
        
        // Record removal event
        HoneycombManager.shared.createEvent(name: "cart.product_removed")
            .addFields([
                "product_id": product.id,
                "product_name": product.name,
                "cart_total_items": items.count,
                "cart_total_cost": totalCost
            ])
            .send()
    }
    
    func clearCart() {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "CartViewModel.clearCart").startSpan()
        
        let previousItemCount = items.count
        span.setAttribute(key: "previous_item_count", value: AttributeValue.int(previousItemCount))
        
        defer { span.end() }
        
        items.removeAll()
        updateTotalCost()
        span.status = .ok
        
        // Record cart clear event
        HoneycombManager.shared.createEvent(name: "cart.cleared")
            .addFields([
                "previous_item_count": previousItemCount
            ])
            .send()
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