import Foundation
import Honeycomb
import OpenTelemetryApi

@MainActor
class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    @Published private(set) var currentSessionId: String
    
    private init() {
        // Use Honeycomb's session ID instead of generating our own
        // but fallback to our own UUID if needed
        // TODO - what the hell did AI hallucinate here??
        self.currentSessionId = Honeycomb.currentSession()?.id ?? UUID().uuidString
    }
    
    /// Get the current session ID for cart operations
    func getSessionId() -> String {
        return currentSessionId
    }
    
    /// Generate a new session ID (called after successful checkout)
    func generateNewSessionId() {
        // this did absolutely nothing, it was a hallucination - no-op for now
    }
    
}
