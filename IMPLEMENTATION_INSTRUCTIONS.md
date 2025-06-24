# iOS OpenTelemetry Demo App Implementation Instructions

## Overview
These instructions guide the implementation of an iOS version of the Android OpenTelemetry Demo App - an astronomy equipment e-commerce shop that demonstrates comprehensive observability patterns in mobile applications.

## Architecture Target

### High-Level Architecture
```
┌─────────────────┐                       ┌─────────────────┐
│    iOS App      │───────────────────────│   Honeycomb     │
│                 │                       │                 │
│ - SwiftUI Views │                       │ - Trace Storage │
│ - ViewModels    │                       │ - Analytics     │
│ - API Clients   │                       │ - Dashboards    │
│ - Honeycomb SDK │                       │ - Queries       │
└─────────────────┘                       └─────────────────┘
```

### iOS App Architecture (MVVM with SwiftUI)
```
┌─────────────────┐
│      View       │  ← SwiftUI Views
│   (SwiftUI)     │
└─────────┬───────┘
          │
┌─────────▼───────┐
│   ViewModel     │  ← Business Logic & State Management
│  (ObservableObject) │
│ - @Published    │
│ - Async/Await   │
│ - Telemetry     │
└─────────┬───────┘
          │
┌─────────▼───────┐
│     Model       │  ← Data Layer
│                 │
│ - API Services  │
│ - Data Models   │
│ - Repository    │
└─────────────────┘
```

## Core Features to Implement

### 1. OpenTelemetry Features (Mirroring Android)
- **Automatic Instrumentation**: App lifecycle, network requests, performance monitoring
- **Manual Instrumentation**: Business logic spans, user interaction events
- **Crash Reporting**: Automatic crash detection and reporting
- **ANR Detection**: Hang detection (iOS equivalent of Android ANR)
- **Slow Render Detection**: Performance monitoring for UI rendering
- **Custom Events**: Business-specific telemetry events
- **Session Management**: Global session tracking

### 2. Application Features
- **Product Catalog**: Browse astronomy equipment with images and details
- **Shopping Cart**: Add/remove products, quantity management
- **Checkout Flow**: Shipping info, payment processing, order confirmation
- **Currency Support**: Multi-currency display
- **Product Recommendations**: Smart product suggestions
- **About Section**: Information about OpenTelemetry features

### 3. Demo-Specific Behaviors
- **Intentional Crashes**: Trigger crashes for telemetry demonstration
- **Intentional Hangs**: Demonstrate ANR/hang detection
- **Slow Animations**: Performance monitoring demonstration

## Implementation Steps

### Phase 1: Project Setup and Dependencies

#### 1.1 Configure Honeycomb Swift SDK Dependencies
Add to your iOS project:
```swift
// Package.swift or Xcode Package Dependencies
dependencies: [
    .package(url: "https://github.com/honeycombio/honeycomb-opentelemetry-swift", from: "0.0.13"),
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter URL: `https://github.com/honeycombio/honeycomb-opentelemetry-swift`
3. Select version 0.0.13 or "Up to Next Minor Version" from 0.0.13

**Important**: Make sure to import both `OpenTelemetryApi` and `OpenTelemetrySdk` in files that need trace propagation functionality.

#### 1.2 Create Configuration System
Create `HoneycombConfiguration.swift`:
```swift
struct HoneycombConfiguration {
    let apiKey: String
    let serviceName: String
    let serviceVersion: String
    let apiEndpoint: String
    let debug: Bool
    
    static func loadFromBundle() throws -> HoneycombConfiguration {
        guard let path = Bundle.main.path(forResource: "honeycomb", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            throw ConfigurationError.fileNotFound
        }
        
        guard let apiKey = plist["HONEYCOMB_API_KEY"] as? String,
              let serviceName = plist["SERVICE_NAME"] as? String,
              let apiEndpoint = plist["API_ENDPOINT"] as? String else {
            throw ConfigurationError.missingRequiredFields
        }
        
        return HoneycombConfiguration(
            apiKey: apiKey,
            serviceName: serviceName,
            serviceVersion: plist["SERVICE_VERSION"] as? String ?? "1.0.0",
            apiEndpoint: apiEndpoint,
            debug: plist["DEBUG"] as? Bool ?? true
        )
    }
}

enum ConfigurationError: Error {
    case fileNotFound
    case missingRequiredFields
}
```

#### 1.3 Initialize Honeycomb SDK
Create `HoneycombManager.swift` (equivalent to `OtelDemoApplication.kt`):
```swift
import Foundation
import Honeycomb

class HoneycombManager {
    static let shared = HoneycombManager()
    private var honeycomb: Honeycomb?
    
    private init() {}
    
    func initialize() throws {
        let config = try HoneycombConfiguration.loadFromBundle()
        
        let options = HoneycombOptions.builder()
            .setAPIKey(config.apiKey)
            .setServiceName(config.serviceName)
            .setServiceVersion(config.serviceVersion)
            .setDebug(config.debug)
            .build()
        
        honeycomb = try Honeycomb.configure(options: options)
        
        print("Honeycomb initialized for service: \(config.serviceName)")
    }
    
    func getTracer() -> Tracer? {
        return honeycomb?.getTracer(instrumentationScopeName: "ios.demo.app")
    }
    
    func getMeter() -> Meter? {
        return honeycomb?.getMeter(instrumentationScopeName: "ios.demo.app")
    }
    
    func addField(key: String, value: Any) {
        honeycomb?.addField(key: key, value: value)
    }
    
    func addFields(_ fields: [String: Any]) {
        honeycomb?.addFields(fields)
    }
    
    func sendNow() {
        honeycomb?.sendNow()
    }
}
```

### Phase 2: Data Models

#### 2.1 Product Models
Create `ProductModels.swift`:
```swift
struct Product: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let picture: String
    let priceUsd: Money
    let categories: [String]
}

struct Money: Codable {
    let currencyCode: String
    let units: Int64
    let nanos: Int32
    
    var doubleValue: Double {
        return Double(units) + Double(nanos) / 1_000_000_000.0
    }
}
```

#### 2.2 Checkout Models
Create `CheckoutModels.swift`:
```swift
struct CheckoutRequest: Codable {
    let userId: String
    let userCurrency: String
    let address: Address
    let email: String
    let creditCard: CreditCard
}

struct Address: Codable {
    let streetAddress: String
    let city: String
    let state: String
    let country: String
    let zipCode: String
}

struct CreditCard: Codable {
    let creditCardNumber: String
    let creditCardCvv: String
    let creditCardExpirationYear: Int
    let creditCardExpirationMonth: Int
}
```

### Phase 3: API Services Layer

#### 3.1 Base HTTP Client
Create `HTTPClient.swift`:
```swift
import Foundation
import Honeycomb
import OpenTelemetryApi
import OpenTelemetrySdk

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// Custom setter for trace propagation headers
private struct HttpTextMapSetter: Setter {
    func set(carrier: inout [String: String], key: String, value: String) {
        carrier[key] = value
    }
}

class HTTPClient {
    private let session: URLSession
    private let baseURL: String
    private let textMapSetter = HttpTextMapSetter()
    
    init(baseURL: String) {
        self.baseURL = baseURL
        // Honeycomb automatically instruments URLSession
        self.session = URLSession.shared
    }
    
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        spanName: String
    ) async throws -> T {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer?.spanBuilder(name: spanName)
            .setActive(true)
            .startSpan()
        
        defer { span?.end() }
        
        // Add span attributes
        span?.setAttribute(key: "http.method", value: method.rawValue)
        span?.setAttribute(key: "http.url", value: "\(baseURL)\(endpoint)")
        
        do {
            let result: T = try await performRequest(
                endpoint: endpoint, 
                method: method, 
                body: body, 
                span: span
            )
            span?.setStatus(.ok)
            return result
        } catch {
            span?.recordException(error)
            span?.setStatus(.error(description: error.localizedDescription))
            throw error
        }
    }
    
    private func performRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        body: Data?,
        span: Span?
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw HTTPError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add trace propagation headers
        if let span = span {
            var propagationHeaders: [String: String] = [:]
            OpenTelemetry.instance.propagators.textMapPropagator.inject(
                spanContext: span.context,
                carrier: &propagationHeaders,
                setter: textMapSetter
            )
            
            // Add all propagation headers to the request
            propagationHeaders.forEach { (key: String, value: String) in
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        
        // Add response status to span
        span?.setAttribute(key: "http.status_code", value: httpResponse.statusCode)
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw HTTPError.statusCode(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum HTTPError: Error {
    case invalidURL
    case invalidResponse
    case statusCode(Int)
}
```

#### 3.2 Product API Service
Create `ProductAPIService.swift`:
```swift
import Foundation
import Honeycomb
import OpenTelemetryApi

class ProductAPIService: ObservableObject {
    private let httpClient: HTTPClient
    
    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }
    
    func fetchProducts(currencyCode: String = "USD") async throws -> [Product] {
        // The HTTPClient will automatically add trace propagation headers
        return try await httpClient.request(
            endpoint: "/products?currency=\(currencyCode)", 
            spanName: "ProductAPIService.fetchProducts"
        )
    }
    
    func fetchProduct(id: String, currencyCode: String = "USD") async throws -> Product {
        // The HTTPClient will automatically add trace propagation headers
        return try await httpClient.request(
            endpoint: "/products/\(id)?currency=\(currencyCode)",
            spanName: "ProductAPIService.fetchProduct"
        )
    }
}
```

#### 3.3 Other Services
Similarly implement:
- `CheckoutAPIService.swift` - Order placement and processing
- `CurrencyAPIService.swift` - Currency list and conversion
- `ShippingAPIService.swift` - Shipping cost calculation
- `RecommendationService.swift` - Product recommendations

**Note**: All API services using the `HTTPClient` will automatically include trace propagation headers (traceparent) in their outgoing HTTP requests, enabling distributed tracing across your microservices architecture.

Example `CheckoutAPIService.swift` with trace propagation:
```swift
import Foundation
import Honeycomb
import OpenTelemetryApi

class CheckoutAPIService: ObservableObject {
    private let httpClient: HTTPClient
    
    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }
    
    func placeOrder(_ request: CheckoutRequest) async throws -> CheckoutResponse {
        let requestData = try JSONEncoder().encode(request)
        
        // This request will automatically include traceparent headers
        return try await httpClient.request(
            endpoint: "/checkout",
            method: .POST,
            body: requestData,
            spanName: "CheckoutAPIService.placeOrder"
        )
    }
}
```

### Phase 4: ViewModels

#### 4.1 Product List ViewModel
Create `ProductListViewModel.swift`:
```swift
import Foundation
import Honeycomb
import OpenTelemetryApi

@MainActor
class ProductListViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let productService: ProductAPIService
    
    init(productService: ProductAPIService) {
        self.productService = productService
    }
    
    func loadProducts(isRefresh: Bool = false) async {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer?.spanBuilder(name: "ProductListViewModel.loadProducts").startSpan()
        
        // Add span attributes
        span?.setAttribute(key: "is_refresh", value: isRefresh)
        span?.setAttribute(key: "view_model", value: "ProductListViewModel")
        
        defer { span?.end() }
        
        isLoading = true
        
        do {
            products = try await productService.fetchProducts()
            span?.setStatus(.ok)
            span?.setAttribute(key: "product_count", value: products.count)
        } catch {
            errorMessage = error.localizedDescription
            span?.recordException(error)
            span?.setStatus(.error(description: error.localizedDescription))
        }
        
        isLoading = false
    }
}
```

#### 4.2 Cart ViewModel
Create `CartViewModel.swift`:
```swift
import Foundation
import Honeycomb
import OpenTelemetryApi

struct CartItem: Identifiable {
    let id = UUID()
    let product: Product
    var quantity: Int
}

@MainActor
class CartViewModel: ObservableObject {
    @Published var items: [CartItem] = []
    @Published var totalCost: Double = 0.0
    
    func addProduct(_ product: Product, quantity: Int = 1) {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer?.spanBuilder(name: "CartViewModel.addProduct").startSpan()
        
        // Add span attributes
        span?.setAttribute(key: "product_id", value: product.id)
        span?.setAttribute(key: "product_name", value: product.name)
        span?.setAttribute(key: "quantity", value: quantity)
        span?.setAttribute(key: "price_usd", value: product.priceUsd.doubleValue)
        
        defer { span?.end() }
        
        // Handle special crash/hang demo conditions
        let currentQuantity = getTotalQuantity(for: product.id)
        let newTotal = currentQuantity + quantity
        
        if product.id == "OLJCESPC7Z" && newTotal == 10 {
            // Trigger intentional crash for demo
            span?.setAttribute(key: "demo_trigger", value: "crash")
            triggerCrashDemo()
        } else if product.id == "OLJCESPC7Z" && newTotal == 9 {
            // Trigger intentional hang for demo
            span?.setAttribute(key: "demo_trigger", value: "hang")
            triggerHangDemo()
        }
        
        // Normal cart logic
        if let existingIndex = items.firstIndex(where: { $0.product.id == product.id }) {
            items[existingIndex].quantity += quantity
        } else {
            items.append(CartItem(product: product, quantity: quantity))
        }
        
        updateTotalCost()
        span?.setStatus(.ok)
        
        // Add fields directly to Honeycomb event
        HoneycombManager.shared.addFields([
            "event_type": "cart.product_added",
            "product_id": product.id,
            "product_name": product.name,
            "quantity": quantity,
            "cart_total_items": items.count,
            "cart_total_cost": totalCost
        ])
        HoneycombManager.shared.sendNow()
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
        HoneycombManager.shared.addFields([
            "event_type": "demo.crash_triggered",
            "trigger": "10_explorascopes",
            "demo_type": "intentional_crash"
        ])
        HoneycombManager.shared.sendNow()
        
        // Intentional crash for telemetry demonstration
        fatalError("Demo crash: Added 10 National Park Foundation Explorascopes")
    }
    
    private func triggerHangDemo() {
        // Record the hang event
        HoneycombManager.shared.addFields([
            "event_type": "demo.hang_triggered",
            "trigger": "9_explorascopes",
            "demo_type": "intentional_hang",
            "duration_seconds": 10
        ])
        HoneycombManager.shared.sendNow()
        
        // Intentional hang for demonstration
        DispatchQueue.main.async {
            Thread.sleep(forTimeInterval: 10.0) // Block main thread
        }
    }
}
```

### Phase 5: SwiftUI Views

#### 5.1 Main App Structure
Create `ContentView.swift`:
```swift
struct ContentView: View {
    @StateObject private var cartViewModel = CartViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                Image("otel_icon")
                    .resizable()
                    .frame(width: 100, height: 100)
                
                Text("OpenTelemetry iOS Demo")
                    .font(.title)
                
                NavigationLink("Go Shopping") {
                    AstronomyShopView()
                        .environmentObject(cartViewModel)
                }
                .buttonStyle(.borderedProminent)
                
                NavigationLink("Learn More") {
                    AboutView()
                }
                .buttonStyle(.bordered)
                
                OTelButton()
            }
        }
    }
}
```

#### 5.2 Product List View
Create `ProductListView.swift`:
```swift
struct ProductListView: View {
    @StateObject private var viewModel: ProductListViewModel
    @EnvironmentObject private var cartViewModel: CartViewModel
    
    var body: some View {
        NavigationView {
            if viewModel.isLoading {
                ProgressView("Loading products...")
            } else {
                List(viewModel.products) { product in
                    ProductRowView(product: product)
                        .onTapGesture {
                            // Navigate to product detail
                        }
                }
                .navigationTitle("Astronomy Shop")
            }
        }
        .task {
            await viewModel.loadProducts()
        }
    }
}
```

#### 5.3 Other Views
Implement:
- `ProductDetailView.swift` - Individual product details with recommendations
- `CartView.swift` - Shopping cart display and management
- `CheckoutView.swift` - Checkout flow with forms
- `AboutView.swift` - OpenTelemetry feature information

### Phase 6: Honeycomb Integration

#### 6.1 Automatic Instrumentation
The Honeycomb Swift SDK (v0.0.13) provides OpenTelemetry-compatible instrumentation:
```swift
// Honeycomb SDK automatically instruments:
// - Network requests (URLSession)
// - App lifecycle events through OpenTelemetry
// Note: Automatic instrumentation is enabled by default when initializing the SDK
```

#### 6.2 Manual Instrumentation Patterns
```swift
import Honeycomb
import OpenTelemetryApi
import OpenTelemetrySdk

// Business Logic Spans (OpenTelemetry style)
func performBusinessOperation() async {
    let tracer = HoneycombManager.shared.getTracer()
    let span = tracer?.spanBuilder(name: "business_operation")
        .setActive(true)  // Important for trace propagation
        .startSpan()
    defer { span?.end() }
    
    span?.setAttribute(key: "user_id", value: currentUserId)
    span?.setAttribute(key: "operation_type", value: "checkout")
    
    do {
        // Business logic - any HTTP calls will automatically include trace headers
        span?.setStatus(.ok)
    } catch {
        span?.recordException(error)
        span?.setStatus(.error(description: error.localizedDescription))
        throw error
    }
}

// Honeycomb Event Pattern (Direct field addition)
func recordUserEvent(action: String, target: String) {
    HoneycombManager.shared.addFields([
        "event_type": "user_interaction",
        "action": action,
        "target": target,
        "timestamp": Date().timeIntervalSince1970
    ])
    HoneycombManager.shared.sendNow()
}

// Custom Business Events (Honeycomb pattern)
func recordBusinessEvent(eventName: String, attributes: [String: Any]) {
    var fields = attributes
    fields["event_type"] = eventName
    
    HoneycombManager.shared.addFields(fields)
    HoneycombManager.shared.sendNow()
}

// Mixed Pattern: OpenTelemetry Spans + Honeycomb Events
func complexBusinessOperation() async {
    // Use OpenTelemetry span for tracing
    let tracer = HoneycombManager.shared.getTracer()
    let span = tracer?.spanBuilder(name: "complex_operation")
        .setActive(true)  // Enables trace propagation
        .startSpan()
    defer { span?.end() }
    
    // Use Honeycomb events for business metrics
    HoneycombManager.shared.addFields([
        "event_type": "business_operation_started",
        "operation_id": UUID().uuidString,
        "user_type": "premium"
    ])
    HoneycombManager.shared.sendNow()
    
    // Business logic here - HTTP calls will include traceparent headers
    span?.setAttribute(key: "result", value: "success")
}

// Trace Propagation Helper for Manual HTTP Requests
func createRequestWithTraceHeaders(url: URL, method: String) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method
    
    // Get current span and inject trace headers
    if let currentSpan = OpenTelemetry.instance.contextProvider.activeSpan {
        var headers: [String: String] = [:]
        let setter = HttpTextMapSetter()
        
        OpenTelemetry.instance.propagators.textMapPropagator.inject(
            spanContext: currentSpan.context,
            carrier: &headers,
            setter: setter
        )
        
        headers.forEach { (key, value) in
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
    
    return request
}

private struct HttpTextMapSetter: Setter {
    func set(carrier: inout [String: String], key: String, value: String) {
        carrier[key] = value
    }
}
```

### Phase 7: Assets and Resources

#### 7.1 Product Images
Copy product images from Android assets:
- `EclipsmartTravelRefractorTelescope.jpg`
- `LensCleaningKit.jpg`
- `NationalParkFoundationExplorascope.jpg`
- `OpticalTubeAssembly.jpg`
- `RedFlashlight.jpg`
- `RoofBinoculars.jpg`
- `SolarFilter.jpg`
- `SolarSystemColorImager.jpg`
- `StarsenseExplorer.jpg`
- `TheCometBook.jpg`

#### 7.2 Configuration Files
Create `honeycomb.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>HONEYCOMB_API_KEY</key>
    <string>your_api_key_here</string>
    <key>SERVICE_NAME</key>
    <string>ios-otel-demo</string>
    <key>SERVICE_VERSION</key>
    <string>1.0.0</string>
    <key>API_ENDPOINT</key>
    <string>https://www.zurelia.honeydemo.io/api</string>
    <key>DEBUG</key>
    <true/>
</dict>
</plist>
```

#### 7.3 Product Data
Create `products.json` (copy from Android assets) or fetch from API.

### Phase 8: Special Demo Features

#### 8.1 Crash Demo Implementation
```swift
func triggerDemoCrash() {
    let tracer = HoneycombManager.shared.getTracer()
    let span = tracer?.spanBuilder(name: "demo_crash").startSpan()
    span?.setAttribute(key: "demo_type", value: "intentional_crash")
    span?.setAttribute(key: "trigger_condition", value: "10_explorascopes")
    
    // Record event before crash using Honeycomb event pattern
    HoneycombManager.shared.addFields([
        "event_type": "demo.crash_about_to_occur",
        "reason": "demonstration",
        "trigger_condition": "10_explorascopes"
    ])
    HoneycombManager.shared.sendNow()
    
    // This will trigger crash reporting
    preconditionFailure("Demo crash for telemetry testing")
}
```

#### 8.2 Hang Demo Implementation
```swift
func triggerHangDemo() {
    let tracer = HoneycombManager.shared.getTracer()
    let span = tracer?.spanBuilder(name: "demo_hang").startSpan()
    span?.setAttribute(key: "demo_type", value: "intentional_hang")
    span?.setAttribute(key: "trigger_condition", value: "9_explorascopes")
    
    // Record event before hang using Honeycomb event pattern
    HoneycombManager.shared.addFields([
        "event_type": "demo.hang_about_to_occur",
        "duration_seconds": 10,
        "trigger_condition": "9_explorascopes"
    ])
    HoneycombManager.shared.sendNow()
    
    // Simulate main thread hang (Honeycomb will automatically detect this)
    DispatchQueue.main.async {
        Thread.sleep(forTimeInterval: 10.0)
    }
}
```

#### 8.3 Slow Animation Demo
```swift
struct SlowCometAnimation: View {
    @State private var isAnimating = false
    
    var body: some View {
        // Intentionally slow animation to trigger performance monitoring
        Circle()
            .fill(Color.orange)
            .frame(width: 50, height: 50)
            .offset(x: isAnimating ? 300 : 0)
            .animation(.linear(duration: 10.0), value: isAnimating) // Very slow
            .onAppear {
                recordSlowAnimationEvent()
                
                // Start span for animation performance
                let tracer = HoneycombManager.shared.getTracer()
                let span = tracer?.spanBuilder(name: "slow_animation_demo").startSpan()
                span?.setAttribute(key: "component", value: "SlowCometAnimation")
                span?.setAttribute(key: "duration_seconds", value: 10.0)
                span?.setAttribute(key: "animation_type", value: "linear_offset")
                
                isAnimating = true
                
                // End span after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                    span?.setStatus(.ok)
                    span?.end()
                }
            }
    }
    
    private func recordSlowAnimationEvent() {
        HoneycombManager.shared.addFields([
            "event_type": "demo.slow_animation_triggered",
            "component": "SlowCometAnimation",
            "trigger": "comet_book_added_to_cart",
            "expected_performance_impact": "high",
            "animation_duration": 10.0
        ])
        HoneycombManager.shared.sendNow()
    }
}
```

## Testing Strategy

### Unit Tests
- Test ViewModels with mock services
- Test API services with mock HTTP responses
- Test OpenTelemetry span creation and attributes

### Integration Tests
- Test complete user flows with telemetry verification
- Test crash and hang detection
- Test performance monitoring

### Manual Testing Scenarios
1. **Product Browsing**: Navigate catalog, verify spans
2. **Shopping Cart**: Add items, trigger demos, verify events
3. **Checkout Flow**: Complete purchase, verify transaction spans
4. **Crash Demo**: Add 10 Explorascopes, verify crash reporting
5. **Hang Demo**: Add 9 Explorascopes, verify hang detection
6. **Slow Animation**: Add Comet Book, verify performance spans

## Development Environment Setup

### Honeycomb Setup
1. Create a Honeycomb account at https://honeycomb.io
2. Create a new dataset for your iOS demo app
3. Generate an API key from your Honeycomb account settings
4. Configure `honeycomb.plist` with your API key and service details

### Running the Demo
1. Configure `honeycomb.plist` with your Honeycomb API key
2. Run iOS app in simulator or device
3. Navigate to your Honeycomb dashboard to view telemetry data
4. Use Honeycomb's query interface to explore traces, spans, and events

### Honeycomb Dashboard Setup
Create useful queries in Honeycomb:
- **App Performance**: Query for slow operations and rendering issues
- **User Journey**: Track user flows through the shopping experience  
- **Error Monitoring**: Monitor crashes, hangs, and API failures
- **Business Metrics**: Track cart additions, checkouts, and product views

## Key Implementation Notes

### Context Propagation
- Honeycomb Swift SDK handles context propagation automatically
- Use proper async/await patterns for clean span hierarchies
- Use defer blocks for guaranteed span cleanup
- Avoid manual context management unless specifically needed

### Performance Considerations
- Honeycomb SDK is designed for minimal overhead
- Telemetry processing happens automatically in background
- Implement efficient state management with SwiftUI best practices
- Use sampling if needed for high-volume applications

### Error Handling
- Comprehensive error recording in spans using `recordException()`
- Honeycomb SDK handles telemetry failures gracefully
- User-friendly error messages with telemetry context

### iOS-Specific Considerations
- App lifecycle events (foreground/background)
- Memory management with ARC
- SwiftUI state management
- iOS-specific performance metrics

## App Initialization

### App Delegate / Scene Delegate Setup
Initialize Honeycomb early in the app lifecycle:

```swift
import SwiftUI
import Honeycomb

@main
struct DemoApp: App {
    init() {
        // Initialize Honeycomb as early as possible
        do {
            try HoneycombManager.shared.initialize()
        } catch {
            print("Failed to initialize Honeycomb: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    recordAppLaunchEvent()
                }
        }
    }
    
    private func recordAppLaunchEvent() {
        HoneycombManager.shared.addFields([
            "event_type": "app.launched",
            "app_version": Bundle.main.appVersionLong,
            "device_model": UIDevice.current.model,
            "ios_version": UIDevice.current.systemVersion,
            "launch_timestamp": Date().timeIntervalSince1970
        ])
        HoneycombManager.shared.sendNow()
    }
}

extension Bundle {
    var appVersionLong: String {
        let version = self.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = self.infoDictionary?["CFBundleVersion"] as? String
        return "\(version ?? "Unknown").\(build ?? "Unknown")"
    }
}
```

This implementation provides a comprehensive iOS equivalent of the Android OpenTelemetry demo app, using the Honeycomb Swift SDK for direct integration with Honeycomb's observability platform. It demonstrates the same observability patterns and business functionality while leveraging iOS-native technologies and the simplified Honeycomb SDK architecture.