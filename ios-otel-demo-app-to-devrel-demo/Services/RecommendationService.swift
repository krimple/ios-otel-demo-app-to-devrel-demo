import Foundation
import Honeycomb
import OpenTelemetryApi

class RecommendationService: ObservableObject {
    private let httpClient: HTTPClient
    
    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }
    
    func getRecommendedProducts(for productId: String, excludeIds: [String] = []) async throws -> [Product] {
        let excludeQuery = excludeIds.isEmpty ? "" : "&exclude=\(excludeIds.joined(separator: ","))"
        
        return try await httpClient.request(
            endpoint: "/recommendations/\(productId)?limit=4\(excludeQuery)",
            spanName: "RecommendationService.getRecommendedProducts"
        )
    }
    
    func getRecommendedProducts(excludeIds: [String] = []) async throws -> [Product] {
        let excludeQuery = excludeIds.isEmpty ? "" : "?exclude=\(excludeIds.joined(separator: ","))"
        
        return try await httpClient.request(
            endpoint: "/recommendations\(excludeQuery)",
            spanName: "RecommendationService.getGeneralRecommendations"
        )
    }
}