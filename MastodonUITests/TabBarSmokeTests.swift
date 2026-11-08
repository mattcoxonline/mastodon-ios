//
//  TabBarSmokeTests.swift
//  MastodonUITests
//

import XCTest

@MainActor
final class TabBarSmokeTests: XCTestCase {

    /// Verifies the "4 + 1" tab bar: Feed, Explore, Compose (action tab in the
    /// center), Notifications, You. Requires a logged-in simulator session.
    func testTabBarHasFiveItemsWithCompose() throws {
        let app = XCUIApplication()
        app.launch()
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 20) else {
            throw XCTSkip("No tab bar visible (simulator session not logged in)")
        }
        let buttons = tabBar.buttons.allElementsBoundByIndex
        let labels = buttons.map(\.label)
        print("TAB BAR LABELS: \(labels)")
        XCTAssertEqual(buttons.count, 5, "expected four tabs plus compose, got: \(labels)")
        XCTAssertTrue(labels.contains("Compose"), "compose tab missing: \(labels)")
        if let composeIndex = labels.firstIndex(of: "Compose") {
            XCTAssertEqual(composeIndex, 2, "compose should be the center item, got: \(labels)")
        }
    }
}
