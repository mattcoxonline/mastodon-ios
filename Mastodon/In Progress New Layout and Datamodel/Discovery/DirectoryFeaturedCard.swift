//  DirectoryFeaturedCard.swift
//  Mastodon
//

import SwiftUI
import MastodonAsset
import MastodonLocalization
import MastodonSDK
import MastodonUI

@Observable
class DirectoryFeaturedModel {
    let accountRowViewModel: AccountRowViewModel
    private(set) var bioLine: String?

    init(accountRowViewModel: AccountRowViewModel, bioLine: String?) {
        self.accountRowViewModel = accountRowViewModel
        self.bioLine = bioLine
    }

    nonisolated static func plainText(fromHTML html: String) -> String? {
        guard let data = html.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else { return nil }
        return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct DirectoryFeaturedCard: View {
    @Environment(MastodonNavigationRouter.self) private var navigator
    @Environment(DirectoryFeaturedModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(L10n.Scene.Discovery.featured.uppercased())
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: Spacing.m) {
                AvatarView(style: .circular, size: .large, avatarSource: .url(model.accountRowViewModel.account.avatarURL))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    MastodonContentView.header(
                        html: model.accountRowViewModel.account.displayInfo.displayName,
                        emojis: model.accountRowViewModel.account.displayInfo.emojis,
                        style: .author(isInlinePreview: false)
                    )
                    .lineLimit(1)
                    if let bioLine = model.bioLine {
                        Text(bioLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(followersLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.m)

                model.accountRowViewModel.relationshipButton.button() {
                    Task {
                        do {
                            try await model.accountRowViewModel.doRelationshipButtonAction(navigator: navigator)
                        } catch {
                            navigator.didReceiveError(error)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.l)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: Radius.l)
            )
        }
        .accessibilityElement(children: .combine)
    }

    private var followersLine: String {
        let count = model.accountRowViewModel.account.metrics.followersCount
        let formatted = MastodonMetricFormatter().string(from: count) ?? "-"
        return "\(formatted) Followers"
    }
}
