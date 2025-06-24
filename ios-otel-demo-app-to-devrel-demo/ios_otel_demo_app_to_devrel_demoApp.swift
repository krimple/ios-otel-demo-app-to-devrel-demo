//
//  ios_otel_demo_app_to_devrel_demoApp.swift
//  ios-otel-demo-app-to-devrel-demo
//
//  Created by Ken Rimple on 6/24/25.
//

import SwiftUI
import Honeycomb

@main
struct ios_otel_demo_app_to_devrel_demoApp: App {
    init() {
        // Initialize Honeycomb as early as possible
        do {
            try HoneycombManager.shared.initialize()
        } catch {
            print("Failed to initialize Honeycomb: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    recordAppLaunchEvent()
                }
        }
    }
    
    private func recordAppLaunchEvent() {
        HoneycombManager.shared.createEvent(name: "app.launched")
            .addFields([
                "app_version": Bundle.main.appVersionLong,
                "device_model": UIDevice.current.model,
                "ios_version": UIDevice.current.systemVersion,
                "launch_timestamp": Date().timeIntervalSince1970
            ])
            .send()
    }
}

extension Bundle {
    var appVersionLong: String {
        let version = self.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = self.infoDictionary?["CFBundleVersion"] as? String
        return "\(version ?? "Unknown").\(build ?? "Unknown")"
    }
}
