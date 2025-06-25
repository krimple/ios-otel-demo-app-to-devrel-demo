//
//  ContentView.swift
//  ios-otel-demo-app-to-devrel-demo
//
//  Created by Ken Rimple on 6/24/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cartViewModel = CartViewModel()
    
    // Initialize services
    private let httpClient: HTTPClient
    private let productService: ProductAPIService
    private let checkoutService: CheckoutAPIService
    private let recommendationService: RecommendationService
    
    init() {
        // Get API endpoint from configuration
        let apiEndpoint: String
        do {
            let config = try HoneycombConfiguration.loadFromBundle()
            apiEndpoint = config.apiEndpoint
        } catch {
            apiEndpoint = "https://www.zurelia.honeydemo.io/api"
        }
        
        self.httpClient = HTTPClient(baseURL: apiEndpoint)
        self.productService = ProductAPIService(httpClient: httpClient)
        self.checkoutService = CheckoutAPIService(httpClient: httpClient)
        self.recommendationService = RecommendationService(httpClient: httpClient)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // App Icon and Title
                VStack(spacing: 16) {
                    Image("telescope")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("OpenTelemetry iOS Demo")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Astronomy Equipment Shop")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Main Navigation Buttons
                VStack(spacing: 16) {
                    NavigationLink(destination: AstronomyShopView()
                        .environmentObject(cartViewModel)
                        .environmentObject(productService)
                        .environmentObject(recommendationService)
                    ) {
                        MainButton(title: "Go Shopping", icon: "cart.fill")
                    }
                    
                    NavigationLink(destination: AboutView()) {
                        MainButton(title: "Learn More", icon: "info.circle", style: .secondary)
                    }
                }
                
                // OpenTelemetry Demo Button
                OTelButton()
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

struct MainButton: View {
    let title: String
    let icon: String
    var style: ButtonStyle = .primary
    
    enum ButtonStyle {
        case primary, secondary
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .foregroundColor(style == .primary ? .white : .blue)
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(style == .primary ? Color.blue : Color.blue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue, lineWidth: style == .secondary ? 2 : 0)
        )
    }
}

struct OTelButton: View {
    var body: some View {
        Button(action: {
            // Record OpenTelemetry button tap
            HoneycombManager.shared.createEvent(name: "ui.button_tapped")
                .addFields([
                "button_name": "otel_demo_button",
                "screen": "main_menu"
            ])
                .send()
        }) {
            VStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text("OpenTelemetry Demo")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
}

#Preview {
    ContentView()
}
