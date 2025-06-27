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
        // Use the same approach as Android - send a preview checkout request
        let previewRequest = CheckoutRequest(
            userId: "shipping-preview",
            userCurrency: "USD", 
            address: address,
            email: "preview@example.com",
            creditCard: CreditCard(
                creditCardNumber: "4111111111111111",
                creditCardCvv: "123",
                creditCardExpirationYear: 2030,
                creditCardExpirationMonth: 12
            ),
            items: items
        )
        
        let requestData = try JSONEncoder().encode(previewRequest)
        
        // Use the checkout endpoint with currency parameter like Android
        let response: CheckoutResponse = try await httpClient.request(
            endpoint: "/checkout",
            method: .POST,
            body: requestData,
            queryParameters: ["currencyCode": "USD"],
            spanName: "CheckoutAPIService.getShippingCost"
        )
        
        return response.shippingCost
    }
}