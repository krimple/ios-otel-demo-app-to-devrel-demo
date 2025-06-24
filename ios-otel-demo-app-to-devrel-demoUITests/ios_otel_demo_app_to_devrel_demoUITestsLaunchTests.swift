//
//  ios_otel_demo_app_to_devrel_demoUITestsLaunchTests.swift
//  ios-otel-demo-app-to-devrel-demoUITests
//
//  Created by Ken Rimple on 6/24/25.
//

import XCTest

final class ios_otel_demo_app_to_devrel_demoUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
