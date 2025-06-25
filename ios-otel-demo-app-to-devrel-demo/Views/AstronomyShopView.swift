import SwiftUI

struct AstronomyShopView: View {
    @EnvironmentObject var cartViewModel: CartViewModel
    @EnvironmentObject var productService: ProductAPIService
    @EnvironmentObject var recommendationService: RecommendationService
    @StateObject private var productListViewModel: ProductListViewModel
    
    init() {
        // We'll properly initialize this in the init when services are available
        self._productListViewModel = StateObject(wrappedValue: ProductListViewModel(
            productService: ProductAPIService(httpClient: HTTPClient(baseURL: "temp"))
        ))
    }
    
    var body: some View {
        TabView {
            ProductListView()
                .environmentObject(productListViewModel)
                .environmentObject(cartViewModel)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Products")
                }
            
            CartView()
                .environmentObject(cartViewModel)
                .tabItem {
                    Image(systemName: "cart")
                    Text("Cart")
                }
        }
        .navigationTitle("Astronomy Shop")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Update the view model with the correct service
            productListViewModel.updateService(productService)
            
            // Record navigation to shop
            HoneycombManager.shared.createEvent(name: "navigation.screen_viewed")
                .addFields([
                    "screen_name": "astronomy_shop",
                    "timestamp": Date().timeIntervalSince1970
                ])
                .send()
        }
    }
}

struct ProductListView: View {
    @EnvironmentObject var viewModel: ProductListViewModel
    @EnvironmentObject var cartViewModel: CartViewModel
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading products...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text("Error loading products")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            Task {
                                await viewModel.loadProducts(isRefresh: true)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.products) { product in
                        NavigationLink(destination: ProductDetailView(product: product)
                            .environmentObject(cartViewModel)
                        ) {
                            ProductRowView(product: product, cartViewModel: cartViewModel)
                        }
                    }
                    .refreshable {
                        await viewModel.loadProducts(isRefresh: true)
                    }
                }
            }
            .navigationTitle("Products")
            .task {
                if viewModel.products.isEmpty {
                    await viewModel.loadProducts()
                }
            }
        }
    }
}

struct ProductRowView: View {
    let product: Product
    let cartViewModel: CartViewModel
    
    var body: some View {
        HStack {
            // Product image placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 80)
                .cornerRadius(8)
                .overlay(
                    Image("telescope")
                        .font(.title)
                        .foregroundColor(.gray)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                Text(product.priceUsd.formattedPrice)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Button(action: {
                cartViewModel.addProduct(product)
                
                // Record add to cart action
                HoneycombManager.shared.createEvent(name: "ui.button_tapped")
                    .addFields([
                        "button_name": "add_to_cart",
                        "screen": "product_list",
                        "product_id": product.id
                    ])
                    .send()
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}