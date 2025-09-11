import Foundation

struct HoneycombConfiguration {
    let apiKey: String
    let serviceName: String
    let serviceVersion: String
    let apiEndpoint: String
    let telemetryEndpoint: String
    let debug: Bool
    
    static func loadFromBundle() throws -> HoneycombConfiguration {
        guard let path = Bundle.main.path(forResource: "honeycomb", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            throw ConfigurationError.fileNotFound
        }
        
        guard let apiKey = plist["HONEYCOMB_API_KEY"] as? String,
              let serviceName = plist["SERVICE_NAME"] as? String,
              let apiEndpoint = plist["API_ENDPOINT"] as? String,
              let telemetryEndpoint = plist["TELEMETRY_ENDPOINT"] as? String
        else {
            throw ConfigurationError.missingRequiredFields
        }
        
        return HoneycombConfiguration(
            apiKey: apiKey,
            serviceName: serviceName,
            serviceVersion: plist["SERVICE_VERSION"] as? String ?? "1.0.1",
            apiEndpoint: apiEndpoint,
            telemetryEndpoint: telemetryEndpoint,
            debug: plist["DEBUG"] as? Bool ?? true
        )
    }
}

enum ConfigurationError: Error {
    case fileNotFound
    case missingRequiredFields
    
    var localizedDescription: String {
        switch self {
        case .fileNotFound:
            return "honeycomb.plist file not found in bundle"
        case .missingRequiredFields:
            return "Required fields missing in honeycomb.plist"
        }
    }
}
