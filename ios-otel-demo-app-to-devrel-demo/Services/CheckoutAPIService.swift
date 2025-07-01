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
        
        print("🛒 CheckoutAPIService.placeOrder - Posting to /checkout")
        print("🛒 SessionId: \(request.userId)")
        print("🛒 Currency: \(request.userCurrency)")
        
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
    
    func getShippingCost(address: Address, items: [CheckoutItem], sessionId: String) async throws -> Money {
        print("🚚 CheckoutAPIService.getShippingCost - Getting shipping cost from /checkout")
        print("🚚 SessionId: \(sessionId)")
        
        // GET on /checkout with sessionId to check for shipping costs from server-side cart
        let response: CheckoutResponse = try await httpClient.request(
            endpoint: "/checkout",
            method: .GET,
            queryParameters: [
                "currencyCode": "USD",
                "sessionId": sessionId
            ],
            spanName: "CheckoutAPIService.getShippingCost"
        )
        
        print("🚚 Got shipping cost: \(response.shippingCost.doubleValue)")
        return response.shippingCost
    }
}