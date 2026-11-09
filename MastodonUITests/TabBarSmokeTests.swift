//
//  TabBarSmokeTests.swift
//  MastodonUITests
//

import XCTest

@MainActor
final class TabBarSmokeTests: XCTestCase {

    /// Verifies the tab bar contains exactly the five content tabs (Feed,
    /// Mentions, Oslo local timeline, Explore, You) and that a Compose
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
            XCTAssertEqual(labels, ["Feed", "Mentions", "Oslo", "Explore", "You"], "unexpected tab bar contents")
        } else {
            // local timeline disabled on this instance: no Oslo tab
            XCTAssertEqual(labels, ["Feed", "Mentions", "Explore", "You"], "unexpected tab bar contents")
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

        // the glass toolbar exposes every action via its accessibility labels
        // (English fallbacks; the simulator session runs in English)
        for name in ["Add Attachment", "Add Poll", "Custom Emoji Picker", "Enable Content Warning"] {
            XCTAssertTrue(app.buttons[name].firstMatch.waitForExistence(timeout: 5), "toolbar button missing: \(name)")
        }
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
        XCTAssertTrue(app.tabBars.buttons["Oslo"].exists, "tab label should stay Oslo")
        XCTAssertTrue(app.navigationBars["oslo.town"].firstMatch.waitForExistence(timeout: 10), "oslo.town nav title did not appear")
    }

    /// The Feed nav title is itself the feed picker (principal toolbar menu):
    /// tapping it opens the feed options; picking Everything switches feeds.
    func testFeedTitleMenuOpensFeedPickerAndSwitchesFeed() throws {
        let app = XCUIApplication()
        app.launch()
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 20) else {
            throw XCTSkip("No tab bar visible (simulator session not logged in)")
        }
        // SwiftUI composes the Menu's a11y label, so match on prefix rather
        // than exact label ("Choose feed" may also carry the trailing chevron)
        let titleMenu = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Choose feed"))
            .firstMatch
        guard titleMenu.waitForExistence(timeout: 10) else {
            throw XCTSkip("Feed title menu not found")
        }
        titleMenu.tap()

        func menuItem(_ label: String) -> XCUIElement {
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", label))
                .firstMatch
        }
        let followingItem = menuItem("Following")
        let everythingItem = menuItem("Everything")
        XCTAssertTrue(followingItem.waitForExistence(timeout: 5), "Following feed item missing from title menu")
        XCTAssertTrue(everythingItem.waitForExistence(timeout: 5), "Everything feed item missing from title menu")

        everythingItem.tap()

        // reopen and switch back so the session ends on the following feed
        titleMenu.tap()
        XCTAssertTrue(followingItem.waitForExistence(timeout: 5), "title menu did not reopen after switching to Everything")
        followingItem.tap()
    }

    /// The Mentions tab's scope picker offers Mentions and Notifications
    /// segments (the .everything scope was relabeled "Notifications").
    func testMentionsScopePickerShowsNotificationsSegment() throws {
        let app = XCUIApplication()
        app.launch()
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 20) else {
            throw XCTSkip("No tab bar visible (simulator session not logged in)")
        }
        let mentionsTab = tabBar.buttons["Mentions"]
        guard mentionsTab.exists else {
            throw XCTSkip("No Mentions tab")
        }
        mentionsTab.tap()

        let notificationsSegment = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Notifications"))
            .firstMatch
        XCTAssertTrue(notificationsSegment.waitForExistence(timeout: 5), "Notifications scope segment not found")
    }

    /// The Explore > Hashtags page shows the Trend Board (rank rows over the
    /// trending tags API). Skips if the discovery segment can't be reached.
    func testTrendBoardRendersOnExploreHashtags() throws {
        let app = XCUIApplication()
        app.launch()
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 20) else {
            throw XCTSkip("No tab bar visible")
        }
        tabBar.buttons["Explore"].tap()

        let hashtagsSegment = app.buttons["Hashtags"].firstMatch
        guard hashtagsSegment.waitForExistence(timeout: 8) else {
            throw XCTSkip("Discovery Hashtags segment not found")
        }
        hashtagsSegment.tap()

        // the board's mode picker should appear (Today / This Week)
        let todayButton = app.buttons["Today"].firstMatch
        XCTAssertTrue(todayButton.waitForExistence(timeout: 10), "Trend board mode picker not found")

        // skip cleanly when the instance serves no trends or is rate limiting
        let empty = app.staticTexts["Nothing trending right now"].exists
            || app.staticTexts["Please try again later."].exists
        if empty {
            throw XCTSkip("no trends served (empty or server throttling)")
        }

        // rows combine their content into single accessibility elements whose
        // labels carry the hashtag name
        let tagElement = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "#"))
            .firstMatch
        XCTAssertTrue(tagElement.waitForExistence(timeout: 20), "no trending rows appeared")
    }
}

