import SwiftUI

struct CheckoutFormView: View {
    @StateObject var viewModel: CheckoutViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                        // Order Summary
                        orderSummarySection
                        
                        // Shipping Information
                        shippingInfoSection
                        
                        // Shipping Cost
                        if viewModel.shippingInfo.isComplete {
                            shippingCostSection
                        }
                        
                        // Payment Information
                        if viewModel.canProceedToPayment {
                            paymentInfoSection
                        }
                        
                        // Place Order Button
                        if viewModel.canPlaceOrder {
                            placeOrderButton
                        }
                        
                        // Error Message
                        if let errorMessage = viewModel.errorMessage {
                            errorSection(errorMessage)
                        }
                }
                .padding()
            }
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                HoneycombManager.shared.createEvent(name: "navigation.screen_viewed")
                    .addFields([
                        "screen_name": "checkout_form",
                        "cart_items": viewModel.cartItems.count,
                        "cart_total": viewModel.subtotal
                    ])
                    .send()
                
                // Auto-calculate shipping if form is already complete
                if viewModel.shippingInfo.isComplete && viewModel.shippingCost == nil {
                    Task {
                        await viewModel.calculateShippingCost()
                    }
                }
            }
        }
        .onChange(of: viewModel.orderResult) { _, newValue in
            if newValue != nil {
                showingConfirmation = true
            }
        }
        .fullScreenCover(isPresented: $showingConfirmation) {
            if let orderResult = viewModel.orderResult {
                NavigationStack {
                    CheckoutConfirmationView(orderResult: orderResult) { success in
                        // Cart clearing is now handled in CheckoutViewModel after successful order
                        // Dismiss both confirmation and checkout views
                        showingConfirmation = false
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var orderSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(viewModel.cartItems) { item in
                HStack {
                    Text(item.product.name)
                        .font(.body)
                    Spacer()
                    Text("×\(item.quantity)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", item.totalPrice))")
                        .font(.body)
                        .fontWeight(.medium)
                }
            }
            
            Divider()
            
            HStack {
                Text("Subtotal")
                    .font(.body)
                Spacer()
                Text("$\(String(format: "%.2f", viewModel.subtotal))")
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            if let shippingCost = viewModel.shippingCost {
                HStack {
                    Text("Shipping")
                        .font(.body)
                    Spacer()
                    Text(shippingCost.formattedPrice)
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                Divider()
                
                HStack {
                    Text("Total")
                        .font(.title3)
                        .fontWeight(.bold)
                    Spacer()
                    Text("$\(String(format: "%.2f", viewModel.total))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var shippingInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Shipping Information")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Pre-filled with test data for easier demo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                TextField("Email", text: $viewModel.shippingInfo.email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                
                TextField("Street Address", text: $viewModel.shippingInfo.streetAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack(spacing: 12) {
                    TextField("City", text: $viewModel.shippingInfo.city)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("State", text: $viewModel.shippingInfo.state)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 100)
                }
                
                HStack(spacing: 12) {
                    TextField("ZIP Code", text: $viewModel.shippingInfo.zipCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 120)
                    
                    TextField("Country", text: $viewModel.shippingInfo.country)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            // Automatically calculate shipping when form is complete
            .onChange(of: viewModel.shippingInfo.isComplete) { isComplete in
                if isComplete {
                    Task {
                        await viewModel.calculateShippingCost()
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var shippingCostSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoadingShipping {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Calculating shipping...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let shippingCost = viewModel.shippingCost {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Shipping cost: \(shippingCost.formattedPrice)")
                        .font(.body)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var paymentInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Payment Information")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Test MasterCard • No real charges")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                TextField("Credit Card Number", text: $viewModel.paymentInfo.creditCardNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                
                HStack(spacing: 12) {
                    Picker("Month", selection: $viewModel.paymentInfo.creditCardExpirationMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text(String(format: "%02d", month)).tag(month)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: 100)
                    
                    Picker("Year", selection: $viewModel.paymentInfo.creditCardExpirationYear) {
                        ForEach(Calendar.current.component(.year, from: Date())...(Calendar.current.component(.year, from: Date()) + 10), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: 100)
                    
                    TextField("CVV", text: $viewModel.paymentInfo.creditCardCvv)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 80)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var placeOrderButton: some View {
        Button(action: {
            Task {
                await viewModel.placeOrder()
            }
        }) {
            HStack {
                if viewModel.isProcessingOrder {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(viewModel.isProcessingOrder ? "Processing..." : "Place Order")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
        .disabled(viewModel.isProcessingOrder)
    }
    
    private func errorSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Error")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
            
            Text(message)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    // For preview only - use mock data
    let config = try! HoneycombConfiguration.loadFromBundle()
    let httpClient = HTTPClient(baseURL: config.apiEndpoint)
    let checkoutService = CheckoutAPIService(httpClient: httpClient)
    let sampleProduct = Product(
        id: "1",
        name: "Sample Telescope",
        description: "A great telescope",
        picture: "telescope",
        priceUsd: Money(currencyCode: "USD", units: 299, nanos: 990000000),
        categories: ["astronomy"]
    )
    let cartItems = [CartItem(product: sampleProduct, quantity: 1)]
    let viewModel = CheckoutViewModel(checkoutService: checkoutService, cartItems: cartItems)
    
    return CheckoutFormView(viewModel: viewModel)
}