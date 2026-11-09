// Copyright © 2026 Mastodon gGmbH. All rights reserved.

import SwiftUI
import MastodonAsset
import MastodonLocalization

struct HomeTimelineChrome: ViewModifier {
    @Environment(MastodonTabViewRouter.self) private var tabViewRouter

    func body(content: Content) -> some View {
        content
            .navigationTitle(tabViewRouter.currentTabBarPlacement.isSidebarAvailable ? (currentHomeFeedName ?? "") : "")
            .toolbar {
                if !tabViewRouter.currentTabBarPlacement.isSidebarAvailable {
                    ToolbarItem(placement: .principal) {
                        Menu {
                            homeTimelineFeedPickerContents
                        } label: {
                            feedTitleLabel
                        }
                    }
                }

                if tabViewRouter.isHomeTimelineFilterAvailable, let homeTimelineModel = tabViewRouter.homeTimelineModel, homeTimelineModel.timeline == .homeTimeline {
                    ToolbarItem(placement: .topBarTrailing) {
                        HomeFeedFilterButton()
                            .environment(homeTimelineModel)
                    }
                }
            }
    }
    
    @ViewBuilder var homeTimelineFeedPickerContents: some View {
        Section {
            feedMenuItem(L10n.Scene.HomeTimeline.TimelineMenu.following, timeline: .homeTimeline, icon: Image(phosphor: .house))
            feedMenuItem(L10n.Scene.HomeTimeline.TimelineMenu.everything, timeline: .everything, icon: Image(phosphor: .globe))
        }
        if !tabViewRouter.lists.isEmpty {
            Section {
                Menu(L10nLookup.Timeline.FeedMenu.customFeeds) {
                    ForEach(tabViewRouter.lists, id: \.self.id) { list in
                        feedMenuItem(list.title, timeline: .list(list.id), icon: Image(phosphor: .rssSimple))
                    }
                }
            }
        }
        if !tabViewRouter.followedHashtags.isEmpty {
            Section {
                Menu(L10n.Scene.HomeTimeline.TimelineMenu.Hashtags.title) {
                    ForEach(tabViewRouter.followedHashtags, id: \.self.name) { hashtag in
                        feedMenuItem("#\(hashtag.name)", timeline: .hashtag(hashtag, includeHeader: false))
                    }
                }
            }
        }
    }
    
    @ViewBuilder func feedMenuItem(_ title: String, timeline: MastodonTimelineType, icon: Image? = nil) -> some View {
        let isSelected = Binding(
            get: { tabViewRouter.homeTimelineModel?.timeline == timeline },
            set: { _ in tabViewRouter.homeTimelineModel?.setTimeline(timeline, navigator: tabViewRouter.navigationRouter(forTab: .home)) }
        )
        if let icon {
            Toggle(isOn: isSelected) { Label(title, icon: icon) }
        } else {
            Toggle(title, isOn: isSelected)
        }
    }
    
    var feedTitleLabel: some View {
        HStack(spacing: Spacing.xs) {
            Text(currentHomeFeedName ?? "")
            Image(systemName: "chevron.up.chevron.down")
                .font(.footnote.weight(.semibold))
        }
        .font(.headline)
        .foregroundStyle(.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10nLookup.Timeline.FeedMenu.buttonA11yLabel)
    }

    var currentHomeFeedName: String? {
        guard let timeline = tabViewRouter.homeTimelineModel?.timeline else { return nil }
        switch timeline {
        case .homeTimeline:
            return L10n.Scene.HomeTimeline.TimelineMenu.following
        case .local:
            return L10n.Scene.HomeTimeline.TimelineMenu.localCommunity
        case .everything:
            return L10n.Scene.HomeTimeline.TimelineMenu.everything
        case .list(let listID):
            return tabViewRouter.lists.first(where: { $0.id == listID })?.title
        case .hashtag(let hashtag, _):
            return "#\(hashtag.name)"
            
        default:
            return nil
        }
    }
}

struct HomeFeedFilterButton: View {
    @Environment(TimelineListViewModel.self) var viewModel
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    
    var body: some View {
        if voiceOverEnabled {
            Menu {
                ActivityFilterToggleRows(showQuotesToggle: true)
            } label: {
                buttonLabel
            }
        } else {
            Button {
                viewModel.isPresentingActivityFilter = !viewModel.isPresentingActivityFilter
            } label: {
                buttonLabel
            }
            .popover(isPresented: Binding<Bool>(
                get: { viewModel.isPresentingActivityFilter },
                set: { isPresented in viewModel.isPresentingActivityFilter = isPresented }
            )) {
                ActivityFilterToggles(showQuotesToggle: true)
                    .environment(viewModel)
            }
        }
    }
    
    private var buttonLabel: some View {
        Label(L10nLookup.Timeline.FeedFilter.buttonA11yLabel, phosphor: .slidersHorizontal)
    }
}
