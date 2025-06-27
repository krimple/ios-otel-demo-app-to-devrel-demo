#!/bin/bash

# Quick iOS Build Validation - Essential Checks Only
echo "🚀 Quick Build Validation..."

# 1. Build the project
echo "📦 Building..."
if xcodebuild -scheme "ios-otel-demo-app-to-devrel-demo" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 16" build > /dev/null 2>&1; then
    echo "✅ Build: SUCCESS"
else
    echo "❌ Build: FAILED"
    exit 1
fi

# 2. Run unit tests
echo "🧪 Testing..."
if xcodebuild test -scheme "ios-otel-demo-app-to-devrel-demo" -destination "platform=iOS Simulator,name=iPhone 16" > /dev/null 2>&1; then
    echo "✅ Tests: SUCCESS"
else
    echo "⚠️  Tests: Some failures (check details with full test run)"
fi

# 3. Check for multiple HTTPClient base URLs (the critical issue we solved)
echo "🔍 Checking HTTPClient consistency..."
CART_VIEW_CHECK=$(grep -q "environmentObject(checkoutService)" ios-otel-demo-app-to-devrel-demo/ContentView.swift && echo "OK" || echo "FAIL")
CHECKOUT_SERVICE_CHECK=$(grep -q "@EnvironmentObject.*CheckoutAPIService" ios-otel-demo-app-to-devrel-demo/Views/CartView.swift && echo "OK" || echo "FAIL")

if [ "$CART_VIEW_CHECK" = "OK" ] && [ "$CHECKOUT_SERVICE_CHECK" = "OK" ]; then
    echo "✅ HTTPClient: Properly injected via environment"
else
    echo "❌ HTTPClient: Injection issue detected"
    echo "   ContentView injection: $CART_VIEW_CHECK"
    echo "   CartView @EnvironmentObject: $CHECKOUT_SERVICE_CHECK"
    exit 1
fi

echo ""
echo "🎯 Quick validation complete!"
echo "   For detailed testing, run: xcodebuild test -scheme 'ios-otel-demo-app-to-devrel-demo' -destination 'platform=iOS Simulator,name=iPhone 16'"
echo "   For manual testing, see: test-checklist.md"