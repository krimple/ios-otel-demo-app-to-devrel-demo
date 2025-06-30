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
            queryParameters: ["currencyCode": request.userCurrency],
            spanName: "CheckoutAPIService.placeOrder"
        )
    }
    
    func getShippingCost(address: Address, items: [CheckoutItem]) async throws -> Money {
        // Create shipping quote request
        let shippingRequest = ShippingQuoteRequest(
            address: address,
            items: items
        )
        
        let requestData = try JSONEncoder().encode(shippingRequest)
        
        // Use dedicated shipping quote endpoint
        let response: ShippingQuoteResponse = try await httpClient.request(
            endpoint: "/shipping",
            method: .POST,
            body: requestData,
            queryParameters: ["currencyCode": "USD"],
            spanName: "CheckoutAPIService.getShippingCost"
        )
        
        return response.cost
    }
}