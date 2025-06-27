# iOS OpenTelemetry Demo - Build Testing Checklist

## 🔧 Automated Build Tests

### 1. Configuration Validation Tests
```swift
// Test: Verify all services use the same HTTPClient base URL
func testHTTPClientConsistency() {
    let config = try! HoneycombConfiguration.loadFromBundle()
    let httpClient = HTTPClient(baseURL: config.apiEndpoint)
    
    let productService = ProductAPIService(httpClient: httpClient)
    let checkoutService = CheckoutAPIService(httpClient: httpClient)
    let recommendationService = RecommendationService(httpClient: httpClient)
    
    XCTAssertEqual(productService.httpClient.baseURL, checkoutService.httpClient.baseURL)
    XCTAssertEqual(checkoutService.httpClient.baseURL, recommendationService.httpClient.baseURL)
}

// Test: Verify configuration loading works
func testHoneycombConfigurationLoading() {
    XCTAssertNoThrow(try HoneycombConfiguration.loadFromBundle())
    let config = try! HoneycombConfiguration.loadFromBundle()
    XCTAssertFalse(config.apiEndpoint.isEmpty)
    XCTAssertFalse(config.apiKey.isEmpty)
    XCTAssertFalse(config.serviceName.isEmpty)
}
```

### 2. Environment Object Validation Tests
```swift
// Test: Verify all required environment objects are provided
func testEnvironmentObjectInjection() {
    let contentView = ContentView()
    // Verify that ContentView creates and injects all required services
    XCTAssertNotNil(contentView.productService)
    XCTAssertNotNil(contentView.checkoutService)
    XCTAssertNotNil(contentView.recommendationService)
}

// Test: Verify CartView can access checkout service
func testCartViewCheckoutServiceAccess() {
    let cartView = CartView()
    // This should not crash when accessing @EnvironmentObject
    XCTAssertNoThrow(cartView.checkoutService)
}
```

### 3. API Endpoint Validation Tests
```swift
// Test: Verify URL construction works correctly
func testURLConstruction() {
    let httpClient = HTTPClient(baseURL: "https://api.example.com")
    
    // Test basic endpoint
    let basicURL = httpClient.constructURL(endpoint: "/products", queryParameters: nil)
    XCTAssertEqual(basicURL?.absoluteString, "https://api.example.com/products")
    
    // Test with query parameters
    let queryURL = httpClient.constructURL(endpoint: "/checkout", queryParameters: ["currencyCode": "USD"])
    XCTAssertEqual(queryURL?.absoluteString, "https://api.example.com/checkout?currencyCode=USD")
    
    // Test with special characters
    let specialURL = httpClient.constructURL(endpoint: "/products", queryParameters: ["search": "test query"])
    XCTAssertNotNil(specialURL)
}
```

## 🧪 Manual Testing Checklist (Run After Each Build)

### Core Flow Tests
- [ ] **App Launch**: App starts without crashes
- [ ] **Navigation**: Can navigate to Shopping view
- [ ] **Product Loading**: Products load successfully (check console for HTTP success logs)
- [ ] **Cart Operations**: Can add/remove items from cart
- [ ] **Checkout Flow**: Can open checkout form
- [ ] **Shipping Calculation**: Can calculate shipping (check console logs for successful API calls)
- [ ] **Order Placement**: Can complete full checkout flow

### Configuration Tests
- [ ] **API Endpoints**: Console shows consistent base URLs across all HTTP requests
- [ ] **OpenTelemetry**: Traces are being sent (check Honeycomb or console logs)
- [ ] **Error Handling**: Errors are properly logged with detailed information

### Edge Case Tests
- [ ] **Network Issues**: App handles network failures gracefully
- [ ] **Invalid Data**: App handles malformed API responses
- [ ] **Empty States**: App shows proper empty states (empty cart, no products)

## 🔍 Console Log Validation

### Expected Success Patterns
```
✅ Successfully created URL: https://[correct-api-endpoint]/products
✅ HTTP Success: Status code 200
✅ Successfully decoded response
✅ Successfully created URL: https://[correct-api-endpoint]/checkout?currencyCode=USD
```

### Red Flags to Watch For
```
❌ Failed to create URL from: [url]
❌ HTTP Error: Status code [4xx/5xx]
❌ JSON Decoding Error: [error]
Multiple different base URLs in logs (indicates HTTPClient inconsistency)
```

## 🚨 Critical Issue Detection

### HTTPClient Consistency Check
**Before each release, verify:**
1. Search codebase for `HTTPClient(baseURL:` - should only appear in ContentView.init()
2. No hardcoded URLs in service initializations
3. All services receive HTTPClient via dependency injection

### Environment Object Chain Verification
**Check injection path:**
1. ContentView creates services ✓
2. ContentView injects into AstronomyShopView ✓
3. CartView receives via @EnvironmentObject ✓
4. No service recreation in view sheets ✓

## 🛠️ Automated Test Commands

### Swift Package Manager Tests
```bash
# Run unit tests
swift test

# Run tests with coverage
swift test --enable-code-coverage
```

### Xcode Build Validation
```bash
# Clean build
xcodebuild clean -scheme "ios-otel-demo-app-to-devrel-demo"

# Build for simulator
xcodebuild -scheme "ios-otel-demo-app-to-devrel-demo" -destination "platform=iOS Simulator,name=iPhone 16" build

# Build for device (if configured)
xcodebuild -scheme "ios-otel-demo-app-to-devrel-demo" -destination "generic/platform=iOS" build
```

### Static Analysis
```bash
# SwiftLint (if configured)
swiftlint

# Check for TODO/FIXME comments
grep -r "TODO\|FIXME" --include="*.swift" ios-otel-demo-app-to-devrel-demo/

# Check for hardcoded URLs
grep -r "http" --include="*.swift" ios-otel-demo-app-to-devrel-demo/ | grep -v "HTTPClient\|httpClient"
```

## 📊 Performance Validation

### Memory Leaks
- [ ] No retain cycles in view models
- [ ] HTTPClient instances are properly shared
- [ ] ObservableObjects are correctly managed

### Network Efficiency
- [ ] No duplicate API calls during normal flows
- [ ] Proper request caching where appropriate
- [ ] Trace propagation headers are included

## 🎯 Integration Test Scenarios

### Happy Path
1. Launch app → Navigate to shop → Add items → Proceed to checkout → Fill form → Calculate shipping → Place order → View confirmation

### Error Path
1. Network disconnected → Attempt checkout → Verify error handling
2. Invalid shipping address → Verify validation
3. API returns 500 → Verify graceful degradation

### Edge Cases
1. Add 10 Explorascopes → Verify crash demo works
2. Add 9 Explorascopes → Verify hang demo works
3. Add Comet Book → Verify slow animation

## 🔄 CI/CD Integration Suggestions

```yaml
# .github/workflows/ios-tests.yml
name: iOS Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build and Test
        run: |
          xcodebuild test -scheme "ios-otel-demo-app-to-devrel-demo" -destination "platform=iOS Simulator,name=iPhone 16"
      - name: Static Analysis
        run: |
          # Check for hardcoded HTTPClient instances
          if grep -r "HTTPClient(baseURL:" --include="*.swift" . | grep -v "ContentView.swift"; then
            echo "❌ Found HTTPClient instantiation outside ContentView"
            exit 1
          fi
          # Check for hardcoded URLs
          if grep -r "https://" --include="*.swift" . | grep -v "HTTPClient\|Configuration\|README"; then
            echo "⚠️ Found potential hardcoded URLs"
          fi
```

This comprehensive testing strategy should catch configuration issues, dependency injection problems, and architectural violations before they reach production.