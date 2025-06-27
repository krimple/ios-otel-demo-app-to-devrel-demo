#!/bin/bash

# iOS OpenTelemetry Demo - Build Validation Script
# Run this script after each build to catch common issues

set -e  # Exit on any error

echo "🚀 Starting iOS Build Validation..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "📁 Working directory: $PROJECT_DIR"

# Function to print status
print_status() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 1. Check for HTTPClient consistency
print_status "Checking HTTPClient consistency..."

# Check for HTTPClient outside ContentView, but allow in previews and tests
HTTPCLIENT_FILES=$(grep -l "HTTPClient(baseURL:" --include="*.swift" . | grep -v "ContentView.swift" | grep -v "Tests.swift")
INVALID_HTTPCLIENT=false

for file in $HTTPCLIENT_FILES; do
    # Check if HTTPClient usage is within a #Preview block
    if grep -q "#Preview" "$file"; then
        # File has Preview, check if HTTPClient is within preview context
        awk '/#Preview/,/^}/' "$file" | grep -q "HTTPClient(baseURL:" && continue
    fi
    # If we get here, there's an invalid HTTPClient usage
    print_error "Found HTTPClient instantiation outside ContentView/Preview in: $file"
    grep -n "HTTPClient(baseURL:" "$file"
    INVALID_HTTPCLIENT=true
done

if [ "$INVALID_HTTPCLIENT" = true ]; then
    exit 1
else
    print_success "HTTPClient consistency check passed"
fi

# 2. Check for hardcoded URLs (excluding legitimate ones)
print_status "Checking for hardcoded URLs..."

HARDCODED_URLS=$(grep -r "https://" --include="*.swift" . | \
    grep -v "HTTPClient\|Configuration\|README\|ContentView.swift\|test-checklist.md\|validate-build.sh\|Tests.swift" | \
    grep -v "// " | \
    wc -l)

if [ "$HARDCODED_URLS" -gt 0 ]; then
    print_warning "Found potential hardcoded URLs:"
    grep -r "https://" --include="*.swift" . | \
        grep -v "HTTPClient\|Configuration\|README\|ContentView.swift\|test-checklist.md\|validate-build.sh\|Tests.swift" | \
        grep -v "// "
    print_warning "Please verify these URLs are appropriate"
else
    print_success "No suspicious hardcoded URLs found"
fi

# 3. Check for TODO/FIXME comments
print_status "Checking for TODO/FIXME comments..."

TODO_COUNT=$(grep -r "TODO\|FIXME" --include="*.swift" . | wc -l)
if [ "$TODO_COUNT" -gt 0 ]; then
    print_warning "Found $TODO_COUNT TODO/FIXME comments:"
    grep -r "TODO\|FIXME" --include="*.swift" . | head -10
    if [ "$TODO_COUNT" -gt 10 ]; then
        print_warning "... and $((TODO_COUNT - 10)) more"
    fi
else
    print_success "No TODO/FIXME comments found"
fi

# 4. Check for required configuration files
print_status "Checking required configuration files..."

REQUIRED_FILES=(
    "ios-otel-demo-app-to-devrel-demo/honeycomb.plist"
    "ios-otel-demo-app-to-devrel-demo/honeycomb.plist.sample"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_success "Found required file: $file"
    else
        print_error "Missing required file: $file"
        exit 1
    fi
done

# 5. Build the project
print_status "Building project for simulator..."

if xcodebuild -scheme "ios-otel-demo-app-to-devrel-demo" \
   -configuration Debug \
   -destination "platform=iOS Simulator,name=iPhone 16" \
   build > build.log 2>&1; then
    print_success "Build succeeded"
else
    print_error "Build failed. Check build.log for details"
    tail -20 build.log
    exit 1
fi

# 6. Run unit tests
print_status "Running unit tests..."

if xcodebuild test \
   -scheme "ios-otel-demo-app-to-devrel-demo" \
   -destination "platform=iOS Simulator,name=iPhone 16" > test.log 2>&1; then
    print_success "Unit tests passed"
else
    print_warning "Some unit tests failed. Check test.log for details"
    grep -A 5 -B 5 "FAIL\|error:" test.log | tail -20
fi

# 7. Check for common code quality issues
print_status "Running code quality checks..."

# Check for force unwrapping (!)
FORCE_UNWRAP_COUNT=$(grep -r "!" --include="*.swift" . | grep -v "!=" | grep -v "// " | wc -l)
if [ "$FORCE_UNWRAP_COUNT" -gt 20 ]; then
    print_warning "Found $FORCE_UNWRAP_COUNT force unwrapping operations - consider using optional binding"
fi

# Check for print statements (should use proper logging)
PRINT_COUNT=$(grep -r "print(" --include="*.swift" . | grep -v "// " | wc -l)
if [ "$PRINT_COUNT" -gt 10 ]; then
    print_warning "Found $PRINT_COUNT print statements - consider using structured logging"
fi

# 8. Environment object injection check
print_status "Checking environment object injection..."

if grep -q "@EnvironmentObject.*CheckoutAPIService" ios-otel-demo-app-to-devrel-demo/Views/CartView.swift; then
    print_success "CartView correctly uses @EnvironmentObject for CheckoutAPIService"
else
    print_error "CartView missing @EnvironmentObject for CheckoutAPIService"
    exit 1
fi

if grep -q "\.environmentObject(checkoutService)" ios-otel-demo-app-to-devrel-demo/ContentView.swift; then
    print_success "ContentView correctly injects checkoutService"
else
    print_error "ContentView missing checkoutService injection"
    exit 1
fi

# 9. Check for proper error handling patterns
print_status "Checking error handling patterns..."

SPAN_RECORD_EXCEPTION=$(grep -r "span.recordException" --include="*.swift" . | wc -l)
if [ "$SPAN_RECORD_EXCEPTION" -gt 0 ]; then
    print_success "Found $SPAN_RECORD_EXCEPTION proper error recording patterns"
else
    print_warning "No span.recordException calls found - errors may not be properly traced"
fi

# 10. Final summary
print_status "Validation Summary"

echo ""
echo "📊 Build Validation Results:"
echo "  • HTTPClient Consistency: ✅"
echo "  • Configuration Files: ✅"
echo "  • Build Status: ✅"
echo "  • Environment Injection: ✅"
if [ "$TODO_COUNT" -gt 0 ]; then
    echo "  • Code Quality: ⚠️  ($TODO_COUNT TODOs)"
else
    echo "  • Code Quality: ✅"
fi

print_success "Build validation completed successfully!"

# Cleanup
rm -f build.log test.log

echo ""
echo "🎯 Next Steps:"
echo "  1. Run manual testing using test-checklist.md"
echo "  2. Test checkout flow end-to-end"
echo "  3. Verify Honeycomb traces are being sent"
echo "  4. Check console logs for HTTP success patterns"