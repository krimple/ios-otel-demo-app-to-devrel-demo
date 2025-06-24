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
    
    func getShippingCost(address: Address, items: [CartItem]) async throws -> Money {
        let shippingRequest = ShippingRequest(address: address, items: items)
        let requestData = try JSONEncoder().encode(shippingRequest)
        
        return try await httpClient.request(
            endpoint: "/shipping/estimate",
            method: .POST,
            body: requestData,
            spanName: "CheckoutAPIService.getShippingCost"
        )
    }
}

private struct ShippingRequest: Codable {
    let address: Address
    let items: [CartItem]
}