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
        
        span.setAttribute(key: "product_id", value: AttributeValue.string(id))
        span.setAttribute(key: "view_model", value: AttributeValue.string("ProductDetailViewModel"))
        
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
            span.setAttribute(key: "product_name", value: AttributeValue.string(loadedProduct.name))
            span.setAttribute(key: "recommendation_count", value: AttributeValue.int(loadedRecommendations.count))
            
            // Record successful load event
            HoneycombManager.shared.createEvent(name: "product_detail.loaded")
                .addFields([
                    "product_id": id,
                    "product_name": loadedProduct.name,
                    "recommendation_count": loadedRecommendations.count,
                    "view_model": "ProductDetailViewModel"
                ])
                .send()
            
        } catch {
            errorMessage = error.localizedDescription
            span.recordException(error)
            span.status = .error(description: error.localizedDescription)
            
            // Record error event
            HoneycombManager.shared.createEvent(name: "product_detail.load_failed")
                .addFields([
                    "product_id": id,
                    "error": error.localizedDescription,
                    "view_model": "ProductDetailViewModel"
                ])
                .send()
        }
        
        isLoading = false
    }
}