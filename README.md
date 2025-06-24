# OpenTelemetry iOS Demo App

This is an iOS app built to demonstrate how to configure and use the Honeycomb Swift SDK to observe app and user behavior in iOS applications.

## Features

The OpenTelemetry iOS Demo App demonstrates the following observability features:

### Automatic Instrumentation
- **Network Request Tracing**: URLSession requests automatically instrumented with trace propagation
- **App Lifecycle Monitoring**: App launch, background, and foreground events
- **Performance Monitoring**: Automatic detection of slow operations and rendering issues

### Manual Instrumentation
- **Business Logic Spans**: Custom spans for shopping cart operations, product loading, and checkout flows
- **User Interaction Events**: Track button taps, navigation, and user journey flows
- **Custom Business Metrics**: Cart additions, product views, and conversion tracking

### Demo-Specific Features
- **Crash Reporting**: Intentional crash when adding exactly 10 National Park Foundation Explorascopes
- **Hang Detection**: Main thread hang when adding exactly 9 National Park Foundation Explorascopes  
- **Slow Render Monitoring**: Intentionally slow animation when adding The Comet Book to demonstrate performance monitoring

### Trace Propagation
- **Distributed Tracing**: All HTTP requests include traceparent headers for end-to-end tracing
- **Service Integration**: Backend services can continue traces started in the mobile app
- **Context Management**: Proper OpenTelemetry context propagation throughout the app

## Architecture

The app follows MVVM architecture with SwiftUI:
- **Models**: Product data models and checkout structures
- **ViewModels**: Business logic with comprehensive telemetry
- **Views**: SwiftUI views with user interaction tracking
- **Services**: API clients with automatic trace propagation
- **Network Layer**: HTTPClient with OpenTelemetry instrumentation

## Getting Started

### Prerequisites
- Xcode 15.0+
- iOS 15.0+
- Honeycomb account and API key

### Installation

1. Clone the repository
2. Open `ios-otel-demo-app-to-devrel-demo.xcodeproj` in Xcode
3. Add the Honeycomb Swift SDK dependency:
   - File → Add Package Dependencies
   - Enter URL: `https://github.com/honeycombio/honeycomb-opentelemetry-swift`
   - Select version 0.0.13

### Configuration

1. Copy `honeycomb.plist` to your project
2. Update the configuration with your Honeycomb details:
   ```xml
   <key>HONEYCOMB_API_KEY</key>
   <string>your_api_key_here</string>
   <key>SERVICE_NAME</key>
   <string>ios-otel-demo</string>
   <key>API_ENDPOINT</key>
   <string>https://www.zurelia.honeydemo.io/api</string>
   ```

### Running the Demo

1. Build and run the app in Xcode
2. Navigate through the astronomy shop
3. Try the demo scenarios:
   - Browse products and add items to cart
   - Add 10 Explorascopes to trigger crash demo
   - Add 9 Explorascopes to trigger hang demo
   - Add The Comet Book to see slow animation demo
4. View telemetry data in your Honeycomb dashboard

## Key Components

### HoneycombManager
Singleton class managing Honeycomb SDK initialization and providing telemetry APIs.

### HTTPClient  
Network client with automatic trace propagation for distributed tracing.

### ViewModels
- `ProductListViewModel`: Product catalog with load telemetry
- `CartViewModel`: Shopping cart with business event tracking
- `ProductDetailViewModel`: Product details with recommendation tracking

### Demo Features
- `SlowCometAnimation`: Intentionally slow animation for performance monitoring
- Crash/hang triggers in `CartViewModel` based on specific product quantities

## Technology Stack
- **Honeycomb Swift SDK**: 0.0.13
- **SwiftUI**: iOS 15+
- **OpenTelemetry**: Compatible APIs
- **URLSession**: Auto-instrumented networking

## Observability Patterns

### Spans
- HTTP requests automatically create spans
- Business operations wrapped in custom spans
- Proper span lifecycle management with defer blocks

### Events  
- User interactions recorded as Honeycomb events
- Business metrics tracked for analytics
- Error and exception recording

### Attributes
- Rich context added to spans and events
- Product IDs, user actions, performance metrics
- Screen names and navigation tracking

## Dashboard Queries

Create these queries in Honeycomb to explore the data:

```
# App Performance
WHERE duration_ms > 1000

# User Journey  
WHERE event_type = "navigation.screen_viewed" | GROUP BY screen_name

# Error Monitoring
WHERE status = "error" | GROUP BY error

# Business Metrics
WHERE event_type = "cart.product_added" | COUNT
```

## Contributing

This is a demonstration app showcasing OpenTelemetry patterns in iOS. Feel free to use as a reference for implementing observability in your own iOS applications.

## License

This project follows the same license as the OpenTelemetry project.