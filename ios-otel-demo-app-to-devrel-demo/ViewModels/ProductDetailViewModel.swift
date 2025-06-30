import Foundation
import Honeycomb
import OpenTelemetryApi

@MainActor
class ProductDetailViewModel: ObservableObject {
    @Published var product: Product?
    @Published var recommendations: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let productService: ProductAPIService
    private let recommendationService: RecommendationService
    
    init(productService: ProductAPIService, recommendationService: RecommendationService) {
        self.productService = productService
        self.recommendationService = recommendationService
    }
    
    func loadProduct(id: String, excludeFromRecommendations: [String] = []) async {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "ProductDetailViewModel.loadProduct")
            .startSpan()
        
        span.setAttribute(key: "app.product.id", value: AttributeValue.string(id))
        span.setAttribute(key: "app.view.model", value: AttributeValue.string("ProductDetailViewModel"))
        
        defer { span.end() }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Load product and recommendations concurrently
            async let productTask = productService.fetchProduct(id: id)
            async let recommendationsTask = recommendationService.getRecommendedProducts(
                for: id, 
                excludeIds: excludeFromRecommendations
            )
            
            let (loadedProduct, loadedRecommendations) = try await (productTask, recommendationsTask)
            
            self.product = loadedProduct
            self.recommendations = loadedRecommendations
            
            span.status = .ok
            span.setAttribute(key: "app.product.name", value: AttributeValue.string(loadedProduct.name))
            span.setAttribute(key: "app.recommendations.count", value: AttributeValue.int(loadedRecommendations.count))
            span.setAttribute(key: "app.operation.status", value: AttributeValue.string("success"))
            
        } catch {
            errorMessage = error.localizedDescription
            span.recordException(error)
            span.status = .error(description: error.localizedDescription)
            span.setAttribute(key: "app.operation.status", value: AttributeValue.string("failed"))
        }
        
        isLoading = false
    }
}