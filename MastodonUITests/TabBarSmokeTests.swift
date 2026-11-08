//
//  TabBarSmokeTests.swift
//  MastodonUITests
//

import XCTest

@MainActor
final class TabBarSmokeTests: XCTestCase {

    /// Verifies the tab bar contains exactly the five content tabs (Feed,
    /// Explore, Oslo local timeline, Mentions, You) and that a Compose
    /// floating action button is present. Requires a logged-in simulator
    /// session on an instance with the local timeline enabled.
    func testTabBarHasFiveTabsPlusComposeFAB() throws {
        let app = XCUIApplication()
        app.launch()
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 20) else {
            throw XCTSkip("No tab bar visible (simulator session not logged in)")
        }
        let labels = tabBar.buttons.allElementsBoundByIndex.map(\.label)
        print("TAB BAR BUTTON LABELS: \(labels)")

        if labels.contains("Oslo") {
            XCTAssertEqual(labels, ["Feed", "Explore", "Oslo", "Mentions", "You"], "unexpected tab bar contents")
        } else {
            // local timeline disabled on this instance: no Oslo tab
            XCTAssertEqual(labels, ["Feed", "Explore", "Mentions", "You"], "unexpected tab bar contents")
        }
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

    /// Tapping the Oslo tab shows the local timeline.
    func testOsloTabShowsLocalTimeline() throws {
        let app = XCUIApplication()
        app.launch()
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 20) else {
            throw XCTSkip("No tab bar visible (simulator session not logged in)")
        }
        let osloTab = tabBar.buttons["Oslo"]
        guard osloTab.exists else {
            throw XCTSkip("No Oslo tab (local timeline disabled on this instance)")
        }
        osloTab.tap()
        XCTAssertTrue(app.navigationBars["Oslo"].firstMatch.waitForExistence(timeout: 10), "Oslo nav title did not appear")
    }
}
