import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 80))
                        .foregroundColor(.orange)
                    
                    Text("OpenTelemetry iOS Demo")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Demonstrating observability patterns in iOS applications")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                
                // Features
                VStack(alignment: .leading, spacing: 16) {
                    Text("Features Demonstrated")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    FeatureRow(
                        icon: "network",
                        title: "Network Tracing",
                        description: "HTTP requests automatically instrumented with trace propagation"
                    )
                    
                    FeatureRow(
                        icon: "eye",
                        title: "User Journey Tracking",
                        description: "Track user flows through the shopping experience"
                    )
                    
                    FeatureRow(
                        icon: "exclamationmark.triangle",
                        title: "Crash Reporting",
                        description: "Automatic crash detection and reporting (add 10 Explorascopes)"
                    )
                    
                    FeatureRow(
                        icon: "clock",
                        title: "Hang Detection",
                        description: "Main thread hang detection (add 9 Explorascopes)"
                    )
                    
                    FeatureRow(
                        icon: "speedometer",
                        title: "Performance Monitoring",
                        description: "Slow render detection (add The Comet Book to cart)"
                    )
                    
                    FeatureRow(
                        icon: "chart.bar",
                        title: "Custom Events",
                        description: "Business metrics and user interaction tracking"
                    )
                }
                .padding()
                
                // Technology Stack
                VStack(alignment: .leading, spacing: 16) {
                    Text("Technology Stack")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        TechRow(name: "Honeycomb Swift SDK", version: "0.0.13")
                        TechRow(name: "SwiftUI", version: "iOS 15+")
                        TechRow(name: "OpenTelemetry", version: "Compatible")
                        TechRow(name: "URLSession", version: "Auto-instrumented")
                    }
                }
                .padding()
                
                // Demo Instructions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Demo Instructions")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        DemoInstruction(
                            step: "1",
                            title: "Crash Demo",
                            description: "Add exactly 10 National Park Foundation Explorascopes to trigger an intentional crash"
                        )
                        
                        DemoInstruction(
                            step: "2",
                            title: "Hang Demo",
                            description: "Add exactly 9 National Park Foundation Explorascopes to trigger a main thread hang"
                        )
                        
                        DemoInstruction(
                            step: "3",
                            title: "Slow Animation",
                            description: "Add any quantity of The Comet Book to see intentionally slow rendering"
                        )
                    }
                }
                .padding()
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Record about view
            HoneycombManager.shared.createEvent(name: "navigation.screen_viewed")
                .addFields([
                "screen_name": "about"
            ])
                .send()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct TechRow: View {
    let name: String
    let version: String
    
    var body: some View {
        HStack {
            Text(name)
                .font(.body)
            Spacer()
            Text(version)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

struct DemoInstruction: View {
    let step: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.orange)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}