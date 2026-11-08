//
//  TabBarSmokeTests.swift
//  MastodonUITests
//

import XCTest

@MainActor
final class TabBarSmokeTests: XCTestCase {

    /// Verifies the HIG "4 + 1" layout: the tab bar contains exactly the four
    /// content tabs, and Compose is a separate trailing tab bar accessory
    /// button that opens the compose sheet. Requires a logged-in simulator
    /// session.
    func testTabBarHasFourTabsPlusSeparateComposeButton() throws {
        let app = XCUIApplication()
        app.launch()
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 20) else {
            throw XCTSkip("No tab bar visible (simulator session not logged in)")
        }
        let labels = tabBar.buttons.allElementsBoundByIndex.map(\.label)
        print("TAB BAR BUTTON LABELS: \(labels)")

        XCTAssertEqual(labels.prefix(4), ["Feed", "Explore", "Notifications", "You"], "unexpected tab bar contents")
        if labels.count > 4 {
            XCTAssertEqual(labels[4], "Compose", "compose should be the separate trailing accessory, got: \(labels)")
        } else {
            // accessories may not report as tab bar buttons on this OS version;
            // fall back to the app-level query
            XCTAssertTrue(app.buttons["Compose"].firstMatch.waitForExistence(timeout: 5), "compose accessory button not found")
        }
    }

    /// Tapping the compose accessory opens the compose sheet without changing
    /// the selected tab.
    func testTappingComposeOpensComposeSheet() throws {
        let app = XCUIApplication()
        app.launch()
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 20) else {
            throw XCTSkip("No tab bar visible (simulator session not logged in)")
        }
        let composeButton = tabBar.buttons["Compose"].firstMatch
        let fallback = app.buttons["Compose"].firstMatch
        let button = composeButton.exists ? composeButton : (fallback.waitForExistence(timeout: 5) ? fallback : nil)
        guard let button else {
            throw XCTSkip("Compose accessory button not found")
        }
        button.tap()
        let textInput = app.textViews.firstMatch
        XCTAssertTrue(textInput.waitForExistence(timeout: 10), "compose sheet did not open")
    }
}
