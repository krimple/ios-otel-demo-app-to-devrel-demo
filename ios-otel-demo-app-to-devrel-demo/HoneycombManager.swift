import Foundation
import Honeycomb
import OpenTelemetryApi

class HoneycombManager {
    static let shared = HoneycombManager()
    
    private init() {}
    
    func initialize() throws {
        let config = try HoneycombConfiguration.loadFromBundle()
        
        let options = try HoneycombOptions.Builder()
            .setAPIKey(config.apiKey)
            .setServiceName(config.serviceName)
            .setServiceVersion(config.serviceVersion)
            .setAPIEndpoint(config.telemetryEndpoint)
            .setURLSessionInstrumentationEnabled(true)
            .setTimeout(2000)
            .setDebug(config.debug)
            .build()
        
        try Honeycomb.configure(options: options)
    }
    
    func getTracer() -> Tracer {
        return OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ios.demo.app", instrumentationVersion: "1.0.1")
    }
    
    func getMeter() -> any Meter {
        return OpenTelemetry.instance.meterProvider.get(name: "ios.demo.app")
    }
    
    // For field-based events, we'll use a simple event builder pattern
    func createEvent(name: String) -> EventBuilder {
        return EventBuilder(name: name)
    }
}

// Simple event builder for field-based telemetry
class EventBuilder {
    private let name: String
    private var attributes: [String: AttributeValue] = [:]
    
    init(name: String) {
        self.name = name
    }
    
    func addField(key: String, value: Any) -> EventBuilder {
        switch value {
        case let stringValue as String:
            attributes[key] = AttributeValue.string(stringValue)
        case let intValue as Int:
            attributes[key] = AttributeValue.int(intValue)
        case let doubleValue as Double:
            attributes[key] = AttributeValue.double(doubleValue)
        case let boolValue as Bool:
            attributes[key] = AttributeValue.bool(boolValue)
        default:
            attributes[key] = AttributeValue.string(String(describing: value))
        }
        return self
    }
    
    func addFields(_ fields: [String: Any]) -> EventBuilder {
        for (key, value) in fields {
            _ = addField(key: key, value: value)
        }
        return self
    }
    
    func send() {
        // Create a span-based event
        let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ios.demo.app")
        let span = tracer.spanBuilder(spanName: name).startSpan()
        
        for (key, value) in attributes {
            span.setAttribute(key: key, value: value)
        }
        
        span.end()
    }
}
