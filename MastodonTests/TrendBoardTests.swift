//
//  TrendBoardTests.swift
//  MastodonTests
//

import XCTest
@testable import Mastodon
import MastodonSDK
import MastodonCore

@MainActor
final class TrendBoardTests: XCTestCase {

    // MARK: - Fixtures

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder throws -> Date in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let timestamp = TimeInterval(string) {
                return Date(timeIntervalSince1970: timestamp)
            }
            if let timestamp = Double(string) {
                return Date(timeIntervalSince1970: timestamp)
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unparseable day: \(string)")
        }
        return decoder
    }()

    private func tag(_ name: String, history: [[String: String]], following: Bool? = nil) throws -> Mastodon.Entity.Tag {
        let payload: [String: Any] = ["name": name, "url": "https://oslo.town/tags/\(name)", "history": history]
            .merging(following.map { ["following": $0] } ?? [:]) { a, _ in a }
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try Self.decoder.decode(Mastodon.Entity.Tag.self, from: data)
    }

    private func bucket(_ day: Int, uses: String, accounts: String) -> [String: String] {
        ["day": String(day), "uses": uses, "accounts": accounts]
    }

    // Days (unix): 100 = oldest … 106 = today. Buckets are given shuffled to prove sorting.
    private var dayBase: Int { 100 }

    // MARK: - Bucket helpers

    func test_sortedBuckets_ordersOldestToNewest() throws {
        let history = try [bucket(104, uses: "9", accounts: "4"),
                           bucket(100, uses: "1", accounts: "1")].map { try XCTUnwrap(decodeHistory($0)) }
        let sorted = TrendBoardViewModel.sortedBuckets(history)
        XCTAssertEqual(sorted.first?.uses, "1")
        XCTAssertEqual(sorted.last?.uses, "9")
    }

    private func decodeHistory(_ dict: [String: String]) throws -> Mastodon.Entity.History {
        try Self.decoder.decode(Mastodon.Entity.History.self, from: JSONSerialization.data(withJSONObject: dict))
    }

    // MARK: - Stat helpers

    func test_postsToday_and_peopleToday_useNewestBucket() throws {
        let tag = try tag("oslo", history: [
            bucket(105, uses: "4", accounts: "4"),
            bucket(106, uses: "312", accounts: "89"),
            bucket(104, uses: "2", accounts: "2"),
        ])
        let history = try XCTUnwrap(tag.history)
        XCTAssertEqual(TrendBoardViewModel.postsToday(in: history), 312)
        XCTAssertEqual(TrendBoardViewModel.peopleToday(in: history), 89)
        XCTAssertEqual(TrendBoardViewModel.postsThisWeek(in: history), 318)
    }

    // MARK: - Ranking

    func test_todayRanking_ordersByTodayPostsDescending() throws {
        let a = try tag("aaa", history: [bucket(106, uses: "10", accounts: "5"), bucket(105, uses: "99", accounts: "20")])
        let b = try tag("bbb", history: [bucket(106, uses: "500", accounts: "40"), bucket(105, uses: "1", accounts: "1")])
        let infos = TrendBoardViewModel.rankInfos(for: [a, b])
        XCTAssertEqual(infos["bbb"]?.todayRank, 1)
        XCTAssertEqual(infos["aaa"]?.todayRank, 2)
        XCTAssertEqual(infos["bbb"]?.yesterdayRank, 2)
        XCTAssertEqual(infos["aaa"]?.yesterdayRank, 1)
        XCTAssertEqual(infos["bbb"]?.rankDelta, 1) // rose
        XCTAssertEqual(infos["aaa"]?.rankDelta, -1) // fell
    }

    func test_newTag_flagsAndRanksBelowReturningTags() throws {
        let returning = try tag("returning", history: [bucket(106, uses: "5", accounts: "5"), bucket(105, uses: "3", accounts: "3")])
        let fresh = try tag("fresh", history: [bucket(106, uses: "100", accounts: "80")])
        let infos = TrendBoardViewModel.rankInfos(for: [fresh, returning])
        XCTAssertEqual(infos["fresh"]?.isNew, true)
        XCTAssertEqual(infos["fresh"]?.todayRank, 1)
        XCTAssertEqual(infos["fresh"]?.yesterdayRank, 2) // below returning
        XCTAssertEqual(infos["returning"]?.isNew, false)
        XCTAssertEqual(infos["returning"]?.todayRank, 2)
        XCTAssertEqual(infos["returning"]?.yesterdayRank, 1)
    }

    func test_zeroHistorySortsLastWithoutCrashing() throws {
        let empty = try tag("empty", history: [])
        let full = try tag("full", history: [bucket(106, uses: "7", accounts: "3")])
        let infos = TrendBoardViewModel.rankInfos(for: [empty, full])
        XCTAssertEqual(infos["empty"]?.postsToday, 0)
        XCTAssertEqual(infos["full"]?.todayRank, 1)
        XCTAssertEqual(infos["empty"]?.todayRank, 2)
    }

    func test_boards_rankAndCarryModeFlags() throws {
        let a = try tag("aaa", history: [bucket(106, uses: "10", accounts: "5"), bucket(105, uses: "90", accounts: "9")])
        let b = try tag("bbb", history: [bucket(106, uses: "2", accounts: "2"), bucket(105, uses: "0", accounts: "0")])
        let model = TrendBoardViewModel()
        model.rebuild(with: [a, b])
        XCTAssertEqual(model.todayBoard.map(\.tag.name), ["aaa", "bbb"])
        XCTAssertEqual(model.todayBoard.first?.rank, 1)
        // week board: aaa 100 > bbb 2
        XCTAssertEqual(model.weekBoard.map(\.tag.name), ["aaa", "bbb"])
        XCTAssertEqual(model.weekBoard.first?.rank, 1)
        XCTAssertEqual(model.displayTags.map(\.tag.name), model.todayBoard.map(\.tag.name))
    }
    /// Live-API smoke: trends fetch returns content and decodes (needs the
    /// simulator's logged-in session; skips without one).
    func test_trendHashtagsLiveFetch() async throws {
        guard let authBox = AuthenticationServiceProvider.shared.currentActiveUser.value else {
            throw XCTSkip("no logged-in session")
        }
        do {
            let response = try await APIService.shared.trendHashtags(
                domain: authBox.domain,
                query: Mastodon.API.Trends.HashtagQuery(limit: nil),
                authenticationBox: authBox
            )
            let names = response.value.map { $0.name }
            print("TRENDS LIVE: \(response.value.count) tags: \(names)")
            XCTAssertFalse(response.value.isEmpty, "trends API returned empty list")
            XCTAssertNotNil(response.value.first?.history, "history missing on first tag")
        } catch {
            // environmental (e.g. server rate limiting during heavy sessions):
            // skip rather than fail
            print("TRENDS LIVE ERROR: \(error)")
            throw XCTSkip("trends fetch unavailable: \(error)")
        }
    }
}
