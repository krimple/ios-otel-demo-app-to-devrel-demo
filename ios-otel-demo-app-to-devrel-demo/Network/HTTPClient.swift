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

enum HTTPError: LocalizedError {
  case status(Int, String)

  var errorDescription: String? {
    switch self {
    case let .status(code, reason):
      return "HTTP \(code) \(reason)"
    }
  }
}

// Custom setter for trace propagation headers
private struct HttpTextMapSetter: Setter {
    func set(carrier: inout [String: String], key: String, value: String) {
        carrier[key] = value
    }
}

class HTTPClient {
    private let baseURL: String
    private let textMapSetter = HttpTextMapSetter()
    private let urlSession: URLSession

    init(baseURL: String) {
        self.baseURL = baseURL
        let configuration = URLSessionConfiguration.default
        self.urlSession = URLSession(configuration: configuration)
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
            
            // TODO - get proper thread - Thread.current unavailable in async
            Honeycomb.log(
                error: error,
                thread: Thread.main
            )
            
            // Only add stacktrace for non-cancelled errors
            if let urlError = error as? URLError, urlError.code == .cancelled {
                // Skip stacktrace for cancelled requests to reduce noise
                span.setAttribute(key: "error.cancelled", value: AttributeValue.bool(true))
            } else {
                span.setAttribute(key: "exception.stacktrace", value: AttributeValue.string(Thread.callStackSymbols.joined(separator: "\n")))
            }
            
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
            span.setAttribute(key: "error.url", value: AttributeValue.string(attemptedURL))
            throw URLError(.badURL)
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
        
        // Add Baggage header with session.id if sessionId is in query parameters
        if let sessionId = queryParameters?["sessionId"] {
            request.setValue("session.id=\(sessionId)", forHTTPHeaderField: "Baggage")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        do {
            // execute the request
            let (data, response) = try await urlSession.data(for: request)
            
            // now figure out the response
            // TODO is this right??
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            // IF it worked great, otherwise :point-down:
            // TODO also this doesn't handle redirects 304/302
            guard 200...299 ~= httpResponse.statusCode else {
                // Record FULL error information in span
                // TODO - review this, it's ugly AI spam (removing span data now
                // for what should be auto recorded by the honeycomb/upstream instrumentation
                
                // TODO - do I even do this? Wouldn't the instrumentation of the API have
                // the error state?
                // Create a simple NSError with the descriptive message
                throw HTTPError.status(httpResponse.statusCode, "invalid response")
            }
            
            // ok, it's < 300 response code
            
            // Handle 204 No Content responses (like DELETE /cart)
            if httpResponse.statusCode == 204 && data.isEmpty {
                // For EmptyResponse, return an empty instance
                if T.self == EmptyResponse.self {
                    return EmptyResponse() as! T
                }
            }
            // otherwise parse and return
            let result = try JSONDecoder().decode(T.self, from: data)
            return result
        } catch {
            // for when it epically blows up (not a standard http response)
            Honeycomb.log(error: error, thread: Thread.main)
            // maybe?
            span.recordException(error)
            throw error
        }
    }
}

