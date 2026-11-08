//
//  TabBarSmokeTests.swift
//  MastodonUITests
//

import XCTest

@MainActor
final class TabBarSmokeTests: XCTestCase {

    /// Verifies the tab bar contains exactly the four content tabs and that a
    /// Compose floating action button is present. Requires a logged-in
    /// simulator session.
    func testTabBarHasFourTabsPlusComposeFAB() throws {
        let app = XCUIApplication()
        app.launch()
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 20) else {
            throw XCTSkip("No tab bar visible (simulator session not logged in)")
        }
        let labels = tabBar.buttons.allElementsBoundByIndex.map(\.label)
        print("TAB BAR BUTTON LABELS: \(labels)")

        XCTAssertEqual(labels, ["Feed", "Explore", "Notifications", "You"], "unexpected tab bar contents")
        XCTAssertTrue(app.buttons["Compose"].firstMatch.waitForExistence(timeout: 5), "compose FAB not found")
    }

    /// Tapping the compose FAB opens the compose sheet over the current tab.
    func testTappingComposeFABOpensComposeSheet() throws {
        let app = XCUIApplication()
        app.launch()
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 20) else {
            throw XCTSkip("No tab bar visible (simulator session not logged in)")
        }
        let composeButton = app.buttons["Compose"].firstMatch
        guard composeButton.waitForExistence(timeout: 10) else {
            throw XCTSkip("Compose FAB not found")
        }
        composeButton.tap()
        let textInput = app.textViews.firstMatch
        XCTAssertTrue(textInput.waitForExistence(timeout: 10), "compose sheet did not open")
    }
}
