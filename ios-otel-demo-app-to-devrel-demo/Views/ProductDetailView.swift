import SwiftUI

struct ProductDetailView: View {
    let product: Product
    @EnvironmentObject var cartViewModel: CartViewModel
    @State private var quantity = 1
    @State private var showingSlowAnimation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Product Image
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 300)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "telescope")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                    )
                
                // Product Info
                VStack(alignment: .leading, spacing: 12) {
                    Text(product.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(product.priceUsd.formattedPrice)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Text("Categories: \(product.categories.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(product.description)
                        .font(.body)
                        .lineSpacing(4)
                }
                .padding(.horizontal)
                
                // Quantity Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quantity")
                        .font(.headline)
                    
                    HStack {
                        Button(action: {
                            if quantity > 1 {
                                quantity -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        
                        Text("\(quantity)")
                            .font(.title2)
                            .frame(minWidth: 50)
                        
                        Button(action: {
                            quantity += 1
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal)
                
                // Add to Cart Button
                Button(action: {
                    cartViewModel.addProduct(product, quantity: quantity)
                    
                    // Check if this is The Comet Book to trigger slow animation
                    if product.id == "HQTGWGPNH4" {
                        showingSlowAnimation = true
                    }
                    
                    // Record add to cart
                    HoneycombManager.shared.createEvent(name: "product.added_to_cart")
                        .addFields([
                            "product_id": product.id,
                            "product_name": product.name,
                            "quantity": quantity,
                            "screen": "product_detail"
                        ])
                        .send()
                }) {
                    HStack {
                        Image(systemName: "cart.badge.plus")
                        Text("Add to Cart")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Slow Animation Demo (for The Comet Book)
                if showingSlowAnimation {
                    SlowCometAnimation()
                        .frame(height: 100)
                        .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Product Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Record product detail view
            HoneycombManager.shared.createEvent(name: "navigation.screen_viewed")
                .addFields([
                    "screen_name": "product_detail",
                    "product_id": product.id,
                    "product_name": product.name
                ])
                .send()
        }
    }
}