import Foundation
import Honeycomb
import OpenTelemetryApi

@MainActor
class ProductListViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var productService: ProductAPIService
    
    var apiService: ProductAPIService {
        return productService
    }
    
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
        span.setAttribute(key: "app.operation.is.refresh", value: AttributeValue.bool(isRefresh))
        span.setAttribute(key: "app.view.model", value: AttributeValue.string("ProductListViewModel"))
        
        defer { span.end() }
        
        isLoading = true
        errorMessage = nil
        
        do {
            products = try await productService.fetchProducts()
            span.status = .ok
            span.setAttribute(key: "app.products.count", value: AttributeValue.int(products.count))
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