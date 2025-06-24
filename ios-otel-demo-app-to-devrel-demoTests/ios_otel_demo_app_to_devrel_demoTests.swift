//
//  ios_otel_demo_app_to_devrel_demoTests.swift
//  ios-otel-demo-app-to-devrel-demoTests
//
//  Created by Ken Rimple on 6/24/25.
//

import Testing
@testable import ios_otel_demo_app_to_devrel_demo

struct ios_otel_demo_app_to_devrel_demoTests {

    @Test func testMoneyFormatting() async throws {
        // Test Money model price formatting
        let money = Money(currencyCode: "USD", units: 101, nanos: 960000000)
        let expectedValue = 101.96
        
        #expect(abs(money.doubleValue - expectedValue) < 0.01)
        #expect(money.formattedPrice.contains("101.96"))
    }
    
    @Test func testProductModel() async throws {
        // Test Product model creation
        let money = Money(currencyCode: "USD", units: 50, nanos: 0)
        let product = Product(
            id: "test123",
            name: "Test Product",
            description: "A test product",
            picture: "test.jpg",
            priceUsd: money,
            categories: ["test"]
        )
        
        #expect(product.id == "test123")
        #expect(product.name == "Test Product")
        #expect(product.priceUsd.doubleValue == 50.0)
        #expect(product.categories.contains("test"))
    }
    
    @Test func testCartItemCalculation() async throws {
        // Test CartItem total price calculation
        let money = Money(currencyCode: "USD", units: 25, nanos: 500000000)
        let product = Product(
            id: "test456",
            name: "Test Product 2",
            description: "Another test product",
            picture: "test2.jpg",
            priceUsd: money,
            categories: ["test"]
        )
        
        let cartItem = CartItem(product: product, quantity: 3)
        let expectedTotal = 25.5 * 3
        
        #expect(abs(cartItem.totalPrice - expectedTotal) < 0.01)
    }

}
