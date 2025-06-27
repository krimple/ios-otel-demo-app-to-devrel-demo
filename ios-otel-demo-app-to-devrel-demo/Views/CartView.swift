import SwiftUI

struct CartView: View {
    @EnvironmentObject var cartViewModel: CartViewModel
    @EnvironmentObject var checkoutService: CheckoutAPIService
    @State private var showingCheckout = false
    
    var body: some View {
        NavigationView {
            Group {
                if cartViewModel.items.isEmpty {
                    VStack {
                        Image(systemName: "cart")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        Text("Your cart is empty")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Add some astronomy equipment to get started!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack {
                        List {
                            ForEach(cartViewModel.items) { item in
                                CartItemRow(item: item, cartViewModel: cartViewModel)
                            }
                            
                            // Total section
                            HStack {
                                Text("Total")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                                Text("$\(String(format: "%.2f", cartViewModel.totalCost))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical)
                        }
                        
                        // Checkout button
                        if !cartViewModel.items.isEmpty {
                            VStack(spacing: 12) {
                                Button(action: {
                                    // Record checkout initiation
                                    HoneycombManager.shared.createEvent(name: "checkout.initiated")
                                        .addFields([
                                            "cart_items": cartViewModel.items.count,
                                            "cart_total": cartViewModel.totalCost
                                        ])
                                        .send()
                                    
                                    showingCheckout = true
                                }) {
                                    HStack {
                                        Image(systemName: "creditcard")
                                        Text("Proceed to Checkout")
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                                
                                Button(action: {
                                    cartViewModel.clearCart()
                                }) {
                                    Text("Clear Cart")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Cart")
            .onAppear {
                // Record cart view
                HoneycombManager.shared.createEvent(name: "navigation.screen_viewed")
                    .addFields([
                        "screen_name": "cart",
                        "cart_items": cartViewModel.items.count,
                        "cart_total": cartViewModel.totalCost
                    ])
                    .send()
            }
            .sheet(isPresented: $showingCheckout) {
                // Use the existing checkout service from environment
                let checkoutViewModel = CheckoutViewModel(checkoutService: checkoutService, cartItems: cartViewModel.items)
                CheckoutFormView(viewModel: checkoutViewModel)
            }
        }
    }
}

struct CartItemRow: View {
    let item: CartItem
    let cartViewModel: CartViewModel
    @EnvironmentObject var productService: ProductAPIService
    
    var body: some View {
        HStack(spacing: 12) {
            // Product image
            AsyncImage(url: URL(string: productService.getImageUrl(for: item.product.picture))) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.product.name)
                    .font(.headline)
                    .lineLimit(2)
                
                Text("Qty: \(item.quantity)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("$\(String(format: "%.2f", item.totalPrice))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            .padding(.leading, 8)
            
            Spacer()
            
            Button(action: {
                cartViewModel.removeProduct(item.product)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}