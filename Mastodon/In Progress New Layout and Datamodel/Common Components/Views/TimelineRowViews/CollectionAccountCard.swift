//  CollectionAccountCard.swift
//  Mastodon
//

import SwiftUI
import SDWebImageSwiftUI
import MastodonUI

/// Option B member card for collection detail screens: inset cover strip, overlapping
/// avatar, display name + username, follow control, and a one-to-two line bio snippet.
struct CollectionAccountCard: View {
    @Environment(MastodonNavigationRouter.self) private var navigator
    @Environment(AccountRowViewModel.self) var viewModel
    let control: AccountRowControl

    private var cardBackground: Color {
        Color(uiColor: .secondarySystemBackground)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverStrip

            HStack(alignment: .center, spacing: Spacing.m) {
                AvatarView(
                    style: .circular,
                    size: .large,
                    avatarSource: .url(viewModel.account.avatarURL)
                )
                .overlay(Circle().stroke(cardBackground, lineWidth: 3))
                .padding(.top, -Spacing.xl)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    MastodonContentView.header(
                        html: viewModel.account.displayInfo.displayName,
                        emojis: viewModel.account.displayInfo.emojis,
                        style: .author(isInlinePreview: false)
                    )
                    .lineLimit(1)
                    Text("@\(viewModel.account.handle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.m)

                switch control {
                case .relationship:
                    viewModel.relationshipButton.button() {
                        Task {
                            do {
                                try await viewModel.doRelationshipButtonAction(navigator: navigator)
                            } catch {
                                navigator.didReceiveError(error)
                            }
                        }
                    }
                case .removeFromCollection(let action):
                    RemoveFromCollectionButton(action: action)
                }
            }
            .padding(.horizontal, Spacing.m)

            if let bioLine = viewModel.bioLine {
                Text(bioLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, Spacing.m)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.m)
            } else {
                Spacer(minLength: Spacing.m)
                    .frame(height: Spacing.m)
            }
        }
        .padding(.top, Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            cardBackground,
            in: RoundedRectangle(cornerRadius: Radius.m)
        )
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var coverStrip: some View {
        if let bannerUrl = viewModel.account.displayInfo.bannerImageUrl {
            WebImage(url: bannerUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Color(uiColor: .tertiarySystemFill)
                }
            }
            .frame(height: 64)
            .clipShape(RoundedRectangle(cornerRadius: Radius.m))
            .padding(.horizontal, Spacing.m)
        } else {
            Color(uiColor: .tertiarySystemFill)
                .frame(height: 64)
                .clipShape(RoundedRectangle(cornerRadius: Radius.m))
                .padding(.horizontal, Spacing.m)
        }
    }
}
