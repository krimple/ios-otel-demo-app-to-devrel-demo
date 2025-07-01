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
        
        
        // Use the working checkout endpoint that React frontend uses
        return try await httpClient.request(
            endpoint: "/checkout",
            method: .POST,
            body: requestData,
            queryParameters: [
                "currencyCode": request.userCurrency,
                "sessionId": request.userId
            ],
            spanName: "CheckoutAPIService.placeOrder"
        )
    }
    
    func getShippingCost(address: Address, items: [CheckoutItem]) async throws -> Money {
        
        // Create itemList JSON matching React frontend format
        let itemListData = try JSONEncoder().encode(items)
        let itemListString = String(data: itemListData, encoding: .utf8) ?? "[]"
        
        // Create address JSON
        let addressData = try JSONEncoder().encode(address)
        let addressString = String(data: addressData, encoding: .utf8) ?? "{}"
        
        
        let queryParams = [
            "itemList": itemListString,
            "currencyCode": "USD",
            "address": addressString
        ]
        
        
        // Use /shipping endpoint matching React frontend pattern
        // The endpoint returns Money directly, not wrapped in a response object
        let shippingCost: Money = try await httpClient.request(
            endpoint: "/shipping",
            method: .GET,
            queryParameters: queryParams,
            spanName: "CheckoutAPIService.getShippingCost"
        )
        
        return shippingCost
    }
}