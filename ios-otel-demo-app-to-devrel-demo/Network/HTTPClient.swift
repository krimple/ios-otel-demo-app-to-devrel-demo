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
            if let httpError = error as? HTTPError {
                print("📊 HTTP Error Details: \(httpError.detailedDescription)")
            }
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
            throw HTTPError.invalidURL
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
            throw HTTPError.invalidResponse
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
            
            // Record FULL response body
            if let responseData = String(data: data, encoding: .utf8) {
                print("📄 Response body: \(responseData)")
                span.setAttribute(key: "http.response.body", value: AttributeValue.string(responseData))
                span.setAttribute(key: "http.response.body_size", value: AttributeValue.int(data.count))
            } else {
                span.setAttribute(key: "http.response.body_size", value: AttributeValue.int(data.count))
                span.setAttribute(key: "http.response.body_encoding", value: AttributeValue.string("non-utf8"))
            }
            
            // Record URL that failed
            span.setAttribute(key: "http.url", value: AttributeValue.string(url.absoluteString))
            
            let httpError = HTTPError.statusCode(httpResponse.statusCode)
            span.recordException(httpError)
            throw httpError
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
            return "HTTP \(code): \(httpStatusMessage(for: code))"
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .invalidURL:
            return "The URL could not be constructed from the provided endpoint and base URL"
        case .invalidResponse:
            return "The server response was not a valid HTTP response"
        case .statusCode(let code):
            return "HTTP \(code) \(httpStatusMessage(for: code)) - \(httpStatusDescription(for: code))"
        }
    }
    
    private func httpStatusMessage(for code: Int) -> String {
        switch code {
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 408: return "Request Timeout"
        case 429: return "Too Many Requests"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        case 504: return "Gateway Timeout"
        default: return "Error"
        }
    }
    
    private func httpStatusDescription(for code: Int) -> String {
        switch code {
        case 400: return "The request was malformed or invalid"
        case 401: return "Authentication is required"
        case 403: return "Access to the resource is forbidden"
        case 404: return "The requested resource was not found"
        case 408: return "The server timed out waiting for the request"
        case 429: return "Too many requests sent too quickly"
        case 500: return "The server encountered an internal error"
        case 502: return "The server received an invalid response from upstream"
        case 503: return "The service is temporarily unavailable"
        case 504: return "The server timed out waiting for upstream response"
        default: return "An HTTP error occurred"
        }
    }
}
