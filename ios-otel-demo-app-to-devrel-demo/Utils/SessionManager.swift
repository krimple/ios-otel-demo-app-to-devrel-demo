import Foundation
import Honeycomb
import OpenTelemetryApi

@MainActor
class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    private let userDefaults = UserDefaults.standard
    private let sessionIdKey = "cart_session_id"
    
    @Published private(set) var currentSessionId: String
    
    private init() {
        // Load existing session ID or create new one
        if let existingSessionId = userDefaults.string(forKey: sessionIdKey) {
            self.currentSessionId = existingSessionId
        } else {
            self.currentSessionId = UUID().uuidString
            self.saveSessionId()
        }
        
        // Record session initialization
        HoneycombManager.shared.createEvent(name: "session.initialized")
            .addFields([
                "session_id": currentSessionId,
                "is_new_session": userDefaults.string(forKey: sessionIdKey) == nil
            ])
            .send()
    }
    
    /// Get the current session ID for cart operations
    func getSessionId() -> String {
        return currentSessionId
    }
    
    /// Generate a new session ID (called after successful checkout)
    func generateNewSessionId() {
        let tracer = HoneycombManager.shared.getTracer()
        let span = tracer.spanBuilder(spanName: "SessionManager.generateNewSessionId").setActive(true).startSpan()
        
        let previousSessionId = currentSessionId
        currentSessionId = UUID().uuidString
        saveSessionId()
        
        span.setAttribute(key: "app.session.previous_id", value: AttributeValue.string(previousSessionId))
        span.setAttribute(key: "app.session.new_id", value: AttributeValue.string(currentSessionId))
        span.setAttribute(key: "app.operation.type", value: AttributeValue.string("session_reset"))
        span.status = .ok
        span.end()
        
        // Record session reset event
        HoneycombManager.shared.createEvent(name: "session.reset")
            .addFields([
                "previous_session_id": previousSessionId,
                "new_session_id": currentSessionId,
                "trigger": "order_completion"
            ])
            .send()
    }
    
    private func saveSessionId() {
        userDefaults.set(currentSessionId, forKey: sessionIdKey)
    }
}