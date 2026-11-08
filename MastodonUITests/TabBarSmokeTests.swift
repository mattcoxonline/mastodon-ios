//
//  TabBarSmokeTests.swift
//  MastodonUITests
//

import XCTest

@MainActor
final class TabBarSmokeTests: XCTestCase {

    /// Verifies the "4 + 1" tab bar: Feed, Explore, Notifications, You, plus a
    /// trailing Compose action item (HIG pattern). Requires a logged-in
    /// simulator session.
    func testTabBarHasFourTabsPlusTrailingCompose() throws {
        let app = XCUIApplication()
        app.launch()
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 20) else {
            throw XCTSkip("No tab bar visible (simulator session not logged in)")
        }
        let buttons = tabBar.buttons.allElementsBoundByIndex
        let labels = buttons.map(\.label)
        print("TAB BAR LABELS: \(labels)")
        XCTAssertEqual(buttons.count, 5, "expected four tabs plus trailing compose, got: \(labels)")
        XCTAssertEqual(labels.firstIndex(of: "Compose"), 4, "compose should be the trailing item, got: \(labels)")
    }
}
