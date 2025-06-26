import Foundation
import Honeycomb
import OpenTelemetryApi

class ProductAPIService: ObservableObject {
    private let httpClient: HTTPClient
    
    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }
    
    func getImageUrl(for picture: String) -> String {
        return ImageLoader.getImageUrl(picture: picture, apiEndpoint: httpClient.apiEndpoint)
    }
    
    func fetchProducts(currencyCode: String = "USD") async throws -> [Product] {
        // The HTTPClient will automatically add trace propagation headers
        return try await httpClient.request(
            endpoint: "/products?currency=\(currencyCode)", 
            spanName: "ProductAPIService.fetchProducts"
        )
    }
    
    func fetchProduct(id: String, currencyCode: String = "USD") async throws -> Product {
        // The HTTPClient will automatically add trace propagation headers
        return try await httpClient.request(
            endpoint: "/products/\(id)?currency=\(currencyCode)",
            spanName: "ProductAPIService.fetchProduct"
        )
    }
}