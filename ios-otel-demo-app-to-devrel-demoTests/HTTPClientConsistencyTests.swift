import XCTest
@testable import ios_otel_demo_app_to_devrel_demo

class HTTPClientConsistencyTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset any global state before each test
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testHoneycombConfigurationLoading() {
        // Test that configuration can be loaded without throwing
        XCTAssertNoThrow(try HoneycombConfiguration.loadFromBundle())
        
        // Test that configuration has required fields
        do {
            let config = try HoneycombConfiguration.loadFromBundle()
            XCTAssertFalse(config.apiEndpoint.isEmpty, "API endpoint should not be empty")
            XCTAssertFalse(config.serviceName.isEmpty, "Service name should not be empty")
            XCTAssertTrue(config.apiEndpoint.hasPrefix("http"), "API endpoint should be a valid URL")
        } catch {
            XCTFail("Configuration loading failed: \(error)")
        }
    }
    
    func testHTTPClientURLConstruction() {
        let httpClient = HTTPClient(baseURL: "https://api.example.com")
        
        // Test basic URL construction
        let basicURL = try? httpClient.constructURL(endpoint: "/products", queryParameters: nil)
        XCTAssertNotNil(basicURL)
        XCTAssertEqual(basicURL?.absoluteString, "https://api.example.com/products")
        
        // Test URL with query parameters
        let queryURL = try? httpClient.constructURL(endpoint: "/checkout", queryParameters: ["currencyCode": "USD"])
        XCTAssertNotNil(queryURL)
        XCTAssertTrue(queryURL?.absoluteString.contains("currencyCode=USD") ?? false)
        
        // Test URL with multiple query parameters
        let multiQueryURL = try? httpClient.constructURL(
            endpoint: "/products", 
            queryParameters: ["currency": "USD", "limit": "10"]
        )
        XCTAssertNotNil(multiQueryURL)
        XCTAssertTrue(multiQueryURL?.absoluteString.contains("currency=USD") ?? false)
        XCTAssertTrue(multiQueryURL?.absoluteString.contains("limit=10") ?? false)
        
        // Test URL with special characters
        let specialURL = try? httpClient.constructURL(
            endpoint: "/search", 
            queryParameters: ["q": "test query & symbols"]
        )
        XCTAssertNotNil(specialURL, "Should handle special characters in query parameters")
    }
    
    func testCheckoutModelsValidation() {
        // Test ShippingInfo validation with defaults
        let shippingInfo = ShippingInfo()
        XCTAssertTrue(shippingInfo.isComplete, "Default shipping info should be complete")
        XCTAssertEqual(shippingInfo.city, "Palo Alto", "Should have default California city")
        XCTAssertEqual(shippingInfo.state, "CA", "Should have California state")
        XCTAssertTrue(shippingInfo.email.contains("telescope.shopper"), "Should have telescope shopper email")
        
        // Test empty shipping info
        var emptyShippingInfo = ShippingInfo()
        emptyShippingInfo.email = ""
        XCTAssertFalse(emptyShippingInfo.isComplete, "Empty email should make shipping info incomplete")
        
        // Test PaymentInfo validation with defaults
        let paymentInfo = PaymentInfo()
        XCTAssertTrue(paymentInfo.isComplete, "Default payment info should be complete")
        XCTAssertEqual(paymentInfo.creditCardNumber, "5555555555554444", "Should have test MasterCard number")
        XCTAssertEqual(paymentInfo.creditCardCvv, "123", "Should have default CVV")
        
        // Test empty payment info
        var emptyPaymentInfo = PaymentInfo()
        emptyPaymentInfo.creditCardNumber = ""
        XCTAssertFalse(emptyPaymentInfo.isComplete, "Empty card number should make payment info incomplete")
    }
    
    func testMoneyFormatting() {
        let money = Money(currencyCode: "USD", units: 29, nanos: 990000000)
        
        // Test double value conversion
        let doubleValue = money.doubleValue
        XCTAssertEqual(doubleValue, 29.99, accuracy: 0.001, "Money should convert to correct double value")
        
        // Test formatted price
        let formattedPrice = money.formattedPrice
        XCTAssertTrue(formattedPrice.contains("29.99"), "Formatted price should contain the amount")
        XCTAssertTrue(formattedPrice.contains("$") || formattedPrice.contains("USD"), "Formatted price should contain currency symbol")
    }
    
    func testCartItemCalculation() {
        let product = Product(
            id: "test-product",
            name: "Test Product",
            description: "Test Description",
            picture: "test.jpg",
            priceUsd: Money(currencyCode: "USD", units: 10, nanos: 0),
            categories: ["test"]
        )
        
        let cartItem = CartItem(product: product, quantity: 3)
        
        XCTAssertEqual(cartItem.totalPrice, 30.0, accuracy: 0.001, "Cart item should calculate total price correctly")
    }
    
    func testHTTPErrorMessages() {
        let invalidURLError = HTTPError.invalidURL
        XCTAssertEqual(invalidURLError.localizedDescription, "Invalid URL")
        
        let invalidResponseError = HTTPError.invalidResponse
        XCTAssertEqual(invalidResponseError.localizedDescription, "Invalid response")
        
        let statusCodeError = HTTPError.statusCode(404)
        XCTAssertEqual(statusCodeError.localizedDescription, "HTTP error: 404")
    }
    
    func testCheckoutRequestCreation() {
        let shippingInfo = ShippingInfo()
        let paymentInfo = PaymentInfo()
        
        let address = Address(
            streetAddress: "123 Main St",
            city: "Test City",
            state: "TS",
            country: "USA",
            zipCode: "12345"
        )
        
        let creditCard = CreditCard(
            creditCardNumber: "4111111111111111",
            creditCardCvv: "123",
            creditCardExpirationYear: 2025,
            creditCardExpirationMonth: 12
        )
        
        let checkoutItems = [CheckoutItem(productId: "test-product", quantity: 1)]
        
        let checkoutRequest = CheckoutRequest(
            userId: "test-user",
            userCurrency: "USD",
            address: address,
            email: "test@example.com",
            creditCard: creditCard,
            items: checkoutItems
        )
        
        XCTAssertEqual(checkoutRequest.userId, "test-user")
        XCTAssertEqual(checkoutRequest.userCurrency, "USD")
        XCTAssertEqual(checkoutRequest.items.count, 1)
        XCTAssertEqual(checkoutRequest.items.first?.productId, "test-product")
    }
    
    func testCheckoutResponseComputation() {
        let checkoutResponse = CheckoutResponse(
            orderId: "12345",
            shippingTrackingId: "TRK-67890",
            shippingCost: Money(currencyCode: "USD", units: 5, nanos: 0),
            shippingAddress: Address(
                streetAddress: "123 Test St",
                city: "Test City",
                state: "TS",
                country: "USA",
                zipCode: "12345"
            ),
            items: []
        )
        
        // Test backward compatibility
        XCTAssertEqual(checkoutResponse.orderNumber, "12345")
        XCTAssertEqual(checkoutResponse.orderId, "12345")
        
        // Test total computation with no items
        XCTAssertEqual(checkoutResponse.total.doubleValue, 5.0, accuracy: 0.001)
    }
    
    func testActualAPIResponseDecoding() {
        // Test with the actual API response format you provided
        let jsonString = """
        {
            "orderId": "0400ea1d-5366-11f0-9b88-1e2f5fa686ec",
            "shippingTrackingId": "b8ff0769-613a-48d6-b23a-13c750564bc9",
            "shippingCost": {
                "currencyCode": "USD",
                "units": 0,
                "nanos": 0
            },
            "shippingAddress": {
                "streetAddress": "Photo like",
                "city": "NYC",
                "state": "NY",
                "country": "USA",
                "zipCode": "08827"
            },
            "items": []
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        
        XCTAssertNoThrow(try JSONDecoder().decode(CheckoutResponse.self, from: jsonData))
        
        let response = try! JSONDecoder().decode(CheckoutResponse.self, from: jsonData)
        XCTAssertEqual(response.orderId, "0400ea1d-5366-11f0-9b88-1e2f5fa686ec")
        XCTAssertEqual(response.orderNumber, "0400ea1d-5366-11f0-9b88-1e2f5fa686ec") // Backward compatibility
        XCTAssertEqual(response.shippingTrackingId, "b8ff0769-613a-48d6-b23a-13c750564bc9")
        XCTAssertEqual(response.shippingCost.doubleValue, 0.0)
        XCTAssertEqual(response.shippingAddress.city, "NYC")
        XCTAssertEqual(response.items.count, 0)
    }
}

// Extension to make HTTPClient testable
extension HTTPClient {
    func constructURL(endpoint: String, queryParameters: [String: String]?) throws -> URL? {
        var urlComponents = URLComponents(string: "\(self.apiEndpoint)\(endpoint)")
        
        if let queryParameters = queryParameters {
            urlComponents?.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        return urlComponents?.url
    }
}