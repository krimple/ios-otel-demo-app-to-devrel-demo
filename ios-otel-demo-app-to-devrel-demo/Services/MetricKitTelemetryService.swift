//
//  MetricKitTelemetryService.swift
//  ios-otel-demo-app-to-devrel-demo
//
//  Created by Ken Rimple on 9/23/25.
//

import Foundation
import Honeycomb
import OpenTelemetryApi

func sendFakeMetrics() {
    reportMetrics(payload: FakeMetricPayload())
    if #available(iOS 14.0, *) {
        reportDiagnostics(payload: FakeDiagnosticPayload())
    }
}

