import Foundation
import Honeycomb
import OpenTelemetryApi
import OpenTelemetrySdk

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// Custom setter for trace propagation headers
private struct HttpTextMapSetter: Setter {
    func set(carrier: inout [String: String], key: String, value: String) {
        carrier[key] = value
    }
}

class HTTPClient {
    private let session: URLSession
    private let baseURL: String
    private let textMapSetter = HttpTextMapSetter()
    
    init(baseURL: String) {
        self.baseURL = baseURL
        // Honeycomb automatically instruments URLSession
        self.session = URLSession.shared
    }
    
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        spanName: String
    ) async throws -> T {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: spanName)
            .startSpan()
        
        defer { span.end() }
        
        // Add span attributes
        span.setAttribute(key: "http.method", value: AttributeValue.string(method.rawValue))
        span.setAttribute(key: "http.url", value: AttributeValue.string("\(baseURL)\(endpoint)"))
        
        do {
            let result: T = try await performRequest(
                endpoint: endpoint, 
                method: method, 
                body: body, 
                span: span
            )
            span.status = .ok
            return result
        } catch {
            span.recordException(error)
            span.status = .error(description: error.localizedDescription)
            throw error
        }
    }
    
    private func performRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        body: Data?,
        span: Span
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw HTTPError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add trace propagation headers
        var propagationHeaders: [String: String] = [:]
        OpenTelemetry.instance.propagators.textMapPropagator.inject(
            spanContext: span.context,
            carrier: &propagationHeaders,
            setter: textMapSetter
        )
        
        // Add all propagation headers to the request
        propagationHeaders.forEach { (key: String, value: String) in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        
        // Add response status to span
        span.setAttribute(key: "http.status_code", value: AttributeValue.int(httpResponse.statusCode))
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw HTTPError.statusCode(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum HTTPError: Error {
    case invalidURL
    case invalidResponse
    case statusCode(Int)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .statusCode(let code):
            return "HTTP error: \(code)"
        }
    }
}
