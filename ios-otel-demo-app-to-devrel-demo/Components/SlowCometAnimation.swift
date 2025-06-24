import SwiftUI
import OpenTelemetryApi

struct SlowCometAnimation: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack {
            Text("Slow Animation Demo")
                .font(.headline)
                .padding(.bottom, 8)
            
            ZStack {
                // Track line
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 2)
                
                // Comet
                Circle()
                    .fill(Color.orange)
                    .frame(width: 30, height: 30)
                    .offset(x: isAnimating ? 150 : -150)
                    .animation(.linear(duration: 10.0), value: isAnimating) // Very slow
                    .overlay(
                        Image(systemName: "sparkles")
                            .foregroundColor(.white)
                            .font(.caption)
                    )
            }
            .frame(height: 50)
            .onAppear {
                recordSlowAnimationEvent()
                
                // Start span for animation performance
                let tracer = HoneycombManager.shared.getTracer()
                let span = tracer.spanBuilder(spanName: "slow_animation_demo").startSpan()
                span.setAttribute(key: "component", value: AttributeValue.string("SlowCometAnimation"))
                span.setAttribute(key: "duration_seconds", value: AttributeValue.double(10.0))
                span.setAttribute(key: "animation_type", value: AttributeValue.string("linear_offset"))
                
                isAnimating = true
                
                // End span after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                    span.status = .ok
                    span.end()
                }
            }
            
            Text("This animation intentionally runs for 10 seconds to demonstrate performance monitoring")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange, lineWidth: 1)
        )
    }
    
    private func recordSlowAnimationEvent() {
        HoneycombManager.shared.createEvent(name: "demo.slow_animation_triggered")
            .addFields([
                "component": "SlowCometAnimation",
                "trigger": "comet_book_added_to_cart",
                "expected_performance_impact": "high",
                "animation_duration": 10.0
            ])
            .send()
    }
}