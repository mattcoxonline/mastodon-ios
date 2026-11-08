//  TrendBoardView.swift
//  Mastodon
//
//  Explore > Hashtags: a ranked Trend Board over the trending tags API.
//  Ranking, movement, and stats are computed client-side from
//  Mastodon.Entity.Tag.history; see Documentation/TrendBoardSpec.md.
//

import SwiftUI
import MastodonCore
import MastodonLocalization
import MastodonSDK
import MastodonUI

@MainActor
@Observable
final class TrendBoardViewModel {

    enum TrendBoardMode: Equatable {
        case today
        case thisWeek
    }

    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    struct RankedTag: Identifiable {
        let tag: Mastodon.Entity.Tag
        let info: RankInfo
        let rank: Int
        let isTodayBoard: Bool

        var id: String { tag.name }
        /// Posts for the value this board ranks by (today's or the weekly total).
        var postsInMode: Int { isTodayBoard ? info.postsToday : info.postsWeek }
    }

    struct RankInfo {
        let postsToday: Int
        let postsWeek: Int
        let peopleToday: Int
        let yesterdayPosts: Int
        var todayRank: Int = 0
        var yesterdayRank: Int = 0
        var isNew: Bool = false
        var rankDelta: Int { yesterdayRank - todayRank }
    }

    private(set) var state: LoadingState = .idle
    var mode: TrendBoardMode = .today

    private(set) var todayBoard: [RankedTag] = []
    private(set) var weekBoard: [RankedTag] = []
    private(set) var updatingTagNames = Set<String>()

    var displayTags: [RankedTag] {
        mode == .today ? todayBoard : weekBoard
    }

    func reload(authBox: MastodonAuthenticationBox) async {
        if state != .loaded {
            state = .loading
        }
        do {
            let response = try await APIService.shared.trendHashtags(
                domain: authBox.domain,
                query: Mastodon.API.Trends.HashtagQuery(limit: nil),
                authenticationBox: authBox
            )
            rebuild(with: response.value)
            state = .loaded
        } catch {
            if state != .loaded {
                state = .failed
            }
        }
    }

    func rebuild(with tags: [Mastodon.Entity.Tag]) { // internal for tests
        let infos = Self.rankInfos(for: tags)
        todayBoard = Self.board(tags: tags, infos: infos, isTodayBoard: true) { $0.postsToday }
        weekBoard = Self.board(tags: tags, infos: infos, isTodayBoard: false) { $0.postsWeek }
    }

    func isUpdating(_ tag: Mastodon.Entity.Tag) -> Bool {
        updatingTagNames.contains(tag.name)
    }

    func toggleFollow(_ tag: Mastodon.Entity.Tag, authBox: MastodonAuthenticationBox) async {
        guard let isFollowing = tag.following else { return }
        updatingTagNames.insert(tag.name)
        defer { updatingTagNames.remove(tag.name) }

        let updated: Mastodon.Entity.Tag?
        if isFollowing {
            updated = try? await APIService.shared.unfollowTag(for: tag.name, authenticationBox: authBox).value
        } else {
            updated = try? await APIService.shared.followTag(for: tag.name, authenticationBox: authBox).value
        }
        guard let updated else { return }
        replace(tag: updated)
    }

    private func replace(tag updated: Mastodon.Entity.Tag) {
        func swap(in source: [RankedTag]) -> [RankedTag] {
            source.map { entry in
                entry.tag.name == updated.name
                    ? RankedTag(tag: updated, info: entry.info, rank: entry.rank, isTodayBoard: entry.isTodayBoard)
                    : entry
            }
        }
        todayBoard = swap(in: todayBoard)
        weekBoard = swap(in: weekBoard)
    }

    // MARK: - Pure ranking helpers (unit-tested)

    /// History buckets ordered oldest → newest by day.
    nonisolated static func sortedBuckets(_ history: [Mastodon.Entity.History]) -> [Mastodon.Entity.History] {
        history.sorted { $0.day < $1.day }
    }

    nonisolated static func postsToday(in history: [Mastodon.Entity.History]) -> Int {
        Int(sortedBuckets(history).last?.uses ?? "") ?? 0
    }

    nonisolated static func postsThisWeek(in history: [Mastodon.Entity.History]) -> Int {
        sortedBuckets(history).reduce(0) { $0 + (Int($1.uses) ?? 0) }
    }

    nonisolated static func peopleToday(in history: [Mastodon.Entity.History]) -> Int {
        Int(sortedBuckets(history).last?.accounts ?? "") ?? 0
    }

    /// Per-tag stats plus two rankings: by today's posts, and by yesterday's
    /// posts (second-newest bucket). Tags with no activity before today are
    /// ranked last and flagged `isNew`.
    nonisolated static func rankInfos(for tags: [Mastodon.Entity.Tag]) -> [String: RankInfo] {
        var infos = [String: RankInfo]()
        for tag in tags {
            let buckets = sortedBuckets(tag.history ?? [])
            let earlierActivity = buckets.dropLast().reduce(0) { $0 + (Int($1.uses) ?? 0) }
            infos[tag.name] = RankInfo(
                postsToday: postsToday(in: tag.history ?? []),
                postsWeek: postsThisWeek(in: tag.history ?? []),
                peopleToday: peopleToday(in: tag.history ?? []),
                yesterdayPosts: buckets.count > 1 ? (Int(buckets[buckets.count - 2].uses) ?? 0) : 0,
                isNew: earlierActivity == 0
            )
        }

        let todayOrder = tags.sorted {
            let a = infos[$0.name]?.postsToday ?? 0
            let b = infos[$1.name]?.postsToday ?? 0
            return a == b ? $0.name < $1.name : a > b
        }
        for (index, tag) in todayOrder.enumerated() {
            infos[tag.name]?.todayRank = index + 1
        }

        let yesterdayOrder = tags.filter { infos[$0.name]?.isNew == false }.sorted {
            let a = infos[$0.name]?.yesterdayPosts ?? 0
            let b = infos[$1.name]?.yesterdayPosts ?? 0
            return a == b ? $0.name < $1.name : a > b
        }
        // new tags rank below every returning tag, offset by their number
        let returningCount = yesterdayOrder.count
        for (index, tag) in yesterdayOrder.enumerated() {
            infos[tag.name]?.yesterdayRank = index + 1
        }
        for tag in tags where infos[tag.name]?.isNew == true {
            infos[tag.name]?.yesterdayRank = returningCount + 1
        }
        return infos
    }

    static func board(
        tags: [Mastodon.Entity.Tag],
        infos: [String: RankInfo],
        isTodayBoard: Bool,
        key: (RankInfo) -> Int
    ) -> [RankedTag] {
        tags
            .compactMap { tag in
                infos[tag.name].map { RankedTag(tag: tag, info: $0, rank: 0, isTodayBoard: isTodayBoard) }
            }
            .sorted {
                let a = key($0.info)
                let b = key($1.info)
                return a == b ? $0.tag.name < $1.tag.name : a > b
            }
            .enumerated()
            .map { index, entry in
                RankedTag(tag: entry.tag, info: entry.info, rank: index + 1, isTodayBoard: isTodayBoard)
            }
    }
}

struct TrendBoardView: View {
    @Environment(MastodonNavigationRouter.self) private var navigator
    @State private var viewModel = TrendBoardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Picker("Ranking", selection: $viewModel.mode) {
                    Text(L10n.Scene.Discovery.TrendBoard.today)
                        .tag(TrendBoardViewModel.TrendBoardMode.today)
                    Text(L10n.Scene.Discovery.TrendBoard.thisWeek)
                        .tag(TrendBoardViewModel.TrendBoardMode.thisWeek)
                }
                .pickerStyle(.segmented)
                .padding(EdgeInsets(top: Spacing.s, leading: Spacing.l, bottom: Spacing.s, trailing: Spacing.l))

                content
            }
        }
        .refreshable {
            guard let authBox = AuthenticationServiceProvider.shared.currentActiveUser.value else { return }
            await viewModel.reload(authBox: authBox)
        }
        .task {
            guard let authBox = AuthenticationServiceProvider.shared.currentActiveUser.value else { return }
            if viewModel.state == .idle {
                await viewModel.reload(authBox: authBox)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            VStack(spacing: Spacing.m) {
                Spacer().frame(height: Spacing.xxl)
                ProgressView()
            }
            .frame(maxWidth: .infinity)
        case .failed:
            VStack(spacing: Spacing.m) {
                Spacer().frame(height: Spacing.xxl)
                Text(L10n.Common.Alerts.Common.pleaseTryAgainLater)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity)
        case .loaded:
            if viewModel.displayTags.isEmpty {
                VStack(spacing: Spacing.m) {
                    Spacer().frame(height: Spacing.xxl)
                    Text(L10n.Scene.Discovery.TrendBoard.nothingTrending)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(Spacing.l)
                .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.displayTags) { entry in
                    TrendBoardRowView(entry: entry, isUpdating: viewModel.isUpdating(entry.tag)) {
                        Task {
                            guard let authBox = AuthenticationServiceProvider.shared.currentActiveUser.value else { return }
                            await viewModel.toggleFollow(entry.tag, authBox: authBox)
                        }
                    }
                    .padding(EdgeInsets(top: Spacing.s, leading: Spacing.l, bottom: Spacing.s, trailing: Spacing.l))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        navigator.push(.timeline(.hashtag(entry.tag, includeHeader: true)))
                    }
                }
            }
        }
    }
}

private struct TrendBoardRowView: View {
    let entry: TrendBoardViewModel.RankedTag
    let isUpdating: Bool
    let onFollowTapped: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            Text("\(entry.rank)")
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(entry.rank <= 3 ? Color.accentColor : Color.secondary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("#\(entry.tag.name)")
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Text(statsLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    movementChip
                }
            }

            Spacer(minLength: Spacing.m)

            WrappedLineChartView(tag: entry.tag)
                .frame(width: 50, height: 26)
                .accessibilityHidden(true)

            if let buttonType {
                buttonType.button {
                    onFollowTapped()
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var statsLine: String {
        let formatter = MastodonMetricFormatter()
        let posts = formatter.string(from: entry.postsInMode) ?? "-"
        let people = formatter.string(from: entry.info.peopleToday) ?? "-"
        return "\(posts) \(L10n.Scene.FollowedTags.Header.posts) · \(people) \(L10n.Scene.FollowedTags.Header.participants)"
    }

    @ViewBuilder private var movementChip: some View {
        if entry.isTodayBoard {
            if entry.info.isNew {
                Text(L10n.Scene.Discovery.TrendBoard.new)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)
                    .padding(EdgeInsets(top: 1, leading: Spacing.xs + 1, bottom: 1, trailing: Spacing.xs + 1))
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            } else if entry.info.rankDelta != 0 {
                let positive = entry.info.rankDelta > 0
                let tint = positive ? Color.green : Color(uiColor: .systemRed)
                Text("\(positive ? "↑" : "↓")\(abs(entry.info.rankDelta))")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(tint)
                    .padding(EdgeInsets(top: 1, leading: Spacing.xs + 1, bottom: 1, trailing: Spacing.xs + 1))
                    .background(tint.opacity(0.12), in: Capsule())
            }
        }
    }

    private var buttonType: RelationshipButtonType? {
        guard entry.tag.following != nil else { return nil }
        if isUpdating {
            return .updating
        }
        return entry.tag.following == true
            ? .iFollowThem(theyFollowMe: false)
            : .iDoNotFollowThem(theyFollowMe: false, theirAccountIsLocked: false)
    }
}
