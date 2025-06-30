import SwiftUI

struct CheckoutConfirmationView: View {
    let orderResult: CheckoutResponse
    let onDismiss: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Success Icon
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                        
                        Text("Order Placed Successfully!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Thank you for your purchase. Your order has been confirmed and will be processed shortly.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Order Details
                    orderDetailsSection
                    
                    // Shipping Information
                    shippingInfoSection
                    
                    // Order Items
                    orderItemsSection
                    
                    // Continue Shopping Button
                    continueShoppingButton
                }
                .padding()
            }
            .navigationTitle("Order Confirmation")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .onAppear {
                HoneycombManager.shared.createEvent(name: "navigation.screen_viewed")
                    .addFields([
                        "screen_name": "checkout_confirmation",
                        "order_number": orderResult.orderId,
                        "order_total": orderResult.total.doubleValue,
                        "items_count": orderResult.items.count
                    ])
                    .send()
            }
        }
    }
    
    private var orderDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Order Number:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(orderResult.orderId)
                        .font(.body)
                        .fontWeight(.medium)
                        .textSelection(.enabled)
                }
                
                HStack {
                    Text("Tracking ID:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(orderResult.shippingTrackingId)
                        .font(.body)
                        .fontWeight(.medium)
                        .textSelection(.enabled)
                }
                
                HStack {
                    Text("Total Amount:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(orderResult.total.formattedPrice)
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Shipping Cost:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(orderResult.shippingCost.formattedPrice)
                        .font(.body)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var shippingInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shipping Address")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(orderResult.shippingAddress.streetAddress)
                    .font(.body)
                
                Text("\(orderResult.shippingAddress.city), \(orderResult.shippingAddress.state) \(orderResult.shippingAddress.zipCode)")
                    .font(.body)
                
                Text(orderResult.shippingAddress.country)
                    .font(.body)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var orderItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Items")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(orderResult.items, id: \.item.id) { orderItem in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(orderItem.item.name)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text(orderItem.item.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Text(orderItem.cost.formattedPrice)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 4)
                
                if orderItem.item.id != orderResult.items.last?.item.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var continueShoppingButton: some View {
        VStack(spacing: 12) {
            Button(action: {
                // Record continue shopping event
                HoneycombManager.shared.createEvent(name: "checkout.continue_shopping")
                    .addFields([
                        "order_number": orderResult.orderId,
                        "order_total": orderResult.total.doubleValue
                    ])
                    .send()
                
                // Call the onDismiss callback to handle navigation and cart clearing
                onDismiss(true)
            }) {
                HStack {
                    Image(systemName: "bag")
                    Text("Continue Shopping")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            
            Text("You will receive an email confirmation shortly with tracking information.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    let sampleProduct = Product(
        id: "1",
        name: "National Park Foundation Telescope",
        description: "Perfect for stargazing and astronomy enthusiasts",
        picture: "telescope",
        priceUsd: Money(currencyCode: "USD", units: 299, nanos: 990000000),
        categories: ["astronomy"]
    )
    
    let orderResult = CheckoutResponse(
        orderId: "ORD-2024-001234",
        shippingTrackingId: "TRK-789123456",
        shippingCost: Money(currencyCode: "USD", units: 15, nanos: 0),
        shippingAddress: Address(
            streetAddress: "123 Main St",
            city: "San Francisco",
            state: "CA",
            country: "USA",
            zipCode: "94102"
        ),
        items: [
            OrderItem(
                item: sampleProduct,
                cost: Money(currencyCode: "USD", units: 299, nanos: 990000000)
            )
        ]
    )
    
    return CheckoutConfirmationView(orderResult: orderResult) { _ in }
}
