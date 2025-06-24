import Foundation
import Honeycomb
import OpenTelemetryApi

@MainActor
class ProductListViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var productService: ProductAPIService
    
    init(productService: ProductAPIService) {
        self.productService = productService
    }
    
    func updateService(_ service: ProductAPIService) {
        self.productService = service
    }
    
    func loadProducts(isRefresh: Bool = false) async {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "ProductListViewModel.loadProducts").startSpan()
        
        // Add span attributes
        span.setAttribute(key: "is_refresh", value: AttributeValue.bool(isRefresh))
        span.setAttribute(key: "view_model", value: AttributeValue.string("ProductListViewModel"))
        
        defer { span.end() }
        
        isLoading = true
        errorMessage = nil
        
        do {
            products = try await productService.fetchProducts()
            span.status = .ok
            span.setAttribute(key: "product_count", value: AttributeValue.int(products.count))
            
            // Record successful load event
            HoneycombManager.shared.createEvent(name: "products.loaded")
                .addFields([
                    "product_count": products.count,
                    "is_refresh": isRefresh,
                    "view_model": "ProductListViewModel"
                ])
                .send()
            
        } catch {
            errorMessage = error.localizedDescription
            span.recordException(error)
            span.status = .error(description: error.localizedDescription)
            
            // Record error event
            HoneycombManager.shared.createEvent(name: "products.load_failed")
                .addFields([
                    "error": error.localizedDescription,
                    "is_refresh": isRefresh,
                    "view_model": "ProductListViewModel"
                ])
                .send()
        }
        
        isLoading = false
    }
}