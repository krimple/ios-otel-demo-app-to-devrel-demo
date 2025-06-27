# iOS OpenTelemetry Demo App Architecture

## Overview

This iOS app demonstrates OpenTelemetry instrumentation patterns with Honeycomb for observability in a SwiftUI-based e-commerce application.

## Core Architecture Patterns

### HTTP Client & Error Handling

**Location**: `Network/HTTPClient.swift`

- **Single HTTPClient Instance**: Reuse the same configured HTTPClient instance across all services via dependency injection
- **Comprehensive Error Logging**: All HTTP errors include full response details in telemetry
- **Status Code Preservation**: HTTP errors maintain actual status codes (e.g., "HTTP 504 Gateway Timeout") instead of generic error abstractions
- **Response Body Capture**: Full response bodies are logged to spans for debugging
- **Trace Propagation**: Automatic OpenTelemetry trace header injection for distributed tracing

```swift
// Example error with full details
"HTTP 504 Gateway Timeout - Response: {\"error\": \"upstream timeout\"}"
```

### OpenTelemetry Instrumentation

**Manager**: `HoneycombManager.swift`

- **Span Attributes**: Rich contextual information including HTTP status, response size, error details
- **Exception Recording**: Use `span.recordException()` for proper error telemetry
- **Event Creation**: Custom events for user interactions and business logic
- **Screen Tracking**: Automatic navigation event creation in view lifecycle

### SwiftUI Patterns

**Dependency Injection**: Environment objects for service injection
```swift
.environmentObject(checkoutService)
```

**Navigation**: Declarative navigation with state-driven sheet presentation
```swift
.sheet(isPresented: $showingCheckout) {
    CheckoutFormView(viewModel: checkoutViewModel)
}
```

### Service Layer Architecture

**Pattern**: Service classes handle API communication and business logic
- `ProductService`: Product catalog operations
- `CartService`: Shopping cart management  
- `CheckoutAPIService`: Checkout flow operations

**Shared HTTPClient**: All services receive the same HTTPClient instance to ensure consistent configuration and telemetry.

### Data Models

**Location**: `Models/`

- **API Models**: Direct JSON mappings for server communication (`CheckoutRequest`, `CheckoutResponse`)
- **UI Models**: Form-friendly structures with validation (`ShippingInfo`, `PaymentInfo`)
- **Computed Properties**: Derived data like totals and formatted prices
- **Default Values**: Pre-filled test data for easier demo testing

### Error Recovery Patterns

1. **Detailed Error Messages**: Include HTTP status codes and response bodies
2. **Span Attribution**: Full error context recorded in OpenTelemetry spans
3. **User-Friendly Display**: Error messages suitable for UI presentation
4. **Debug Information**: Complete technical details available in telemetry

### Checkout Flow Implementation

**Multi-Step Process**:
1. Cart Review → Shipping Info → Payment Info → Order Placement
2. Progressive disclosure UI based on form completion state
3. Default test data pre-filled for demo purposes
4. Comprehensive error handling with OpenTelemetry instrumentation

**State Management**: 
- `CheckoutViewModel`: Centralized state for checkout process
- Form validation with computed properties
- Async operations with proper error handling

### Testing Strategy

**Unit Tests**: `HTTPClientConsistencyTests.swift`
- Configuration validation
- URL construction verification  
- Error message format testing
- Model serialization/deserialization

**Integration Testing**: Manual validation scripts in repository root

## Key Decisions & Rationale

### Error Handling Simplification
- **Problem**: Custom error enums were creating confusing messages like "HTTPError error 0"
- **Solution**: Use `NSError` with descriptive messages containing actual HTTP status codes and response bodies
- **Benefit**: Clear debugging information in both UI and telemetry

### Single HTTPClient Pattern
- **Problem**: Multiple HTTPClient instances caused configuration inconsistencies
- **Solution**: Dependency injection of shared HTTPClient instance
- **Benefit**: Consistent telemetry and configuration across all network operations

### Default Test Data
- **Problem**: Manual data entry slowed demo testing
- **Solution**: Pre-filled shipping and payment forms with test data
- **Benefit**: Faster checkout flow testing and demonstration

## Dependencies

- **OpenTelemetry Swift**: Distributed tracing and metrics
- **Honeycomb OpenTelemetry**: Observability backend integration
- **SwiftUI**: Declarative UI framework
- **Foundation**: Core networking with URLSession

## Continuous Integration

**GitHub Actions Setup**: `.github/workflows/ci.yml`

- **Runner Environment**: macOS-15 with Xcode 16.0 for project format 77 compatibility
- **iOS Simulator**: iPhone 16 simulator for automated testing
- **Deployment Target**: iOS 18.0 (compatible with GitHub runner limitations)
- **Swift Package Caching**: Optimized build times through dependency caching
- **Parallel Jobs**: Unit tests and UI tests run in separate jobs for efficiency

**Test Strategy**:
- Unit tests run first with comprehensive HTTP client and model validation
- UI tests execute only after unit tests pass
- Environment-specific test skipping for CI compatibility
- Detailed failure reporting with full build logs

**Build Configuration**:
- Code signing disabled for CI environment (`CODE_SIGNING_ALLOWED=NO`)
- Project format 77 support requiring Xcode 16+
- Automatic Swift package resolution and caching

## File Organization

```
ios-otel-demo-app-to-devrel-demo/
├── .github/workflows/   # CI/CD configuration
├── Models/              # Data structures and API models
├── Network/             # HTTP client and networking
├── Services/            # Business logic services
├── Views/               # SwiftUI view components
├── ViewModels/          # MVVM view models
├── Tests/               # Unit and UI test suites
└── Configuration/       # App configuration and setup
```