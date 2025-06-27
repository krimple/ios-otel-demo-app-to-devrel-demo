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
    
    var apiEndpoint: String {
        return baseURL
    }
    
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        queryParameters: [String: String]? = nil,
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
                queryParameters: queryParameters,
                span: span
            )
            span.status = .ok
            return result
        } catch {
            // Log the specific error details
            print("❌ Request failed: \(error)")
            span.recordException(error)
            span.status = .error(description: error.localizedDescription)
            throw error
        }
    }
    
    private func performRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        body: Data?,
        queryParameters: [String: String]?,
        span: Span
    ) async throws -> T {
        var urlComponents = URLComponents(string: "\(baseURL)\(endpoint)")
        
        if let queryParameters = queryParameters {
            urlComponents?.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = urlComponents?.url else {
            let attemptedURL = "\(baseURL)\(endpoint)" + (queryParameters?.map { "?\($0.key)=\($0.value)" }.joined(separator: "&") ?? "")
            print("❌ Failed to create URL from: \(attemptedURL)")
            span.setAttribute(key: "error.url", value: AttributeValue.string(attemptedURL))
            throw URLError(.badURL)
        }
        
        print("✅ Successfully created URL: \(url.absoluteString)")
        
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
            throw URLError(.badServerResponse)
        }
        
        // Add response status to span
        span.setAttribute(key: "http.status_code", value: AttributeValue.int(httpResponse.statusCode))
        
        guard 200...299 ~= httpResponse.statusCode else {
            print("❌ HTTP Error: Status code \(httpResponse.statusCode)")
            
            // Record FULL error information in span
            span.setAttribute(key: "error", value: AttributeValue.bool(true))
            span.setAttribute(key: "http.status_code", value: AttributeValue.int(httpResponse.statusCode))
            span.setAttribute(key: "http.status_text", value: AttributeValue.string(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)))
            
            // Record ALL response headers
            for (headerName, headerValue) in httpResponse.allHeaderFields {
                if let name = headerName as? String, let value = headerValue as? String {
                    span.setAttribute(key: "http.response.header.\(name.lowercased())", value: AttributeValue.string(value))
                }
            }
            
            // Build error message with status code and response body
            var errorMessage = "HTTP \(httpResponse.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
            
            // Record FULL response body and add to error message
            if let responseData = String(data: data, encoding: .utf8) {
                print("📄 Response body: \(responseData)")
                span.setAttribute(key: "http.response.body", value: AttributeValue.string(responseData))
                span.setAttribute(key: "http.response.body_size", value: AttributeValue.int(data.count))
                
                // Add response body to error message if not empty
                if !responseData.isEmpty {
                    errorMessage += " - Response: \(responseData)"
                }
            } else {
                span.setAttribute(key: "http.response.body_size", value: AttributeValue.int(data.count))
                span.setAttribute(key: "http.response.body_encoding", value: AttributeValue.string("non-utf8"))
            }
            
            // Record URL that failed
            span.setAttribute(key: "http.url", value: AttributeValue.string(url.absoluteString))
            
            // Create a simple NSError with the descriptive message
            let error = NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: errorMessage
            ])
            span.recordException(error)
            throw error
        }
        
        print("✅ HTTP Success: Status code \(httpResponse.statusCode)")
        
        do {
            let result = try JSONDecoder().decode(T.self, from: data)
            print("✅ Successfully decoded response")
            return result
        } catch {
            print("❌ JSON Decoding Error: \(error)")
            if let responseData = String(data: data, encoding: .utf8) {
                print("📄 Raw response: \(responseData)")
            }
            span.setAttribute(key: "error.json_decode", value: AttributeValue.string(error.localizedDescription))
            span.recordException(error)
            throw error
        }
    }
}

