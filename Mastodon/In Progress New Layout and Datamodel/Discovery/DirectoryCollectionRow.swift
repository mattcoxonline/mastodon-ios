//  DirectoryCollectionRow.swift
//  Mastodon
//

import SwiftUI
import MastodonLocalization

struct DirectoryCollectionRow: View {
    @Environment(MastodonNavigationRouter.self) private var navigator
    @Environment(CollectionViewModel.self) var viewModel

    static let defaultEmoji = "🗂"

    var body: some View {
        HStack(alignment: .center, spacing: standardPadding) {
            tile
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(L10nLookup.Scene.Collections.numberOfAccounts(viewModel.itemCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var splitTitle: (emoji: String?, title: String) {
        Self.firstEmoji(inTitle: viewModel.collection.name ?? "")
    }

    private var title: String {
        Self.displayTitle(forTitle: viewModel.collection.name ?? "")
    }

    private var tile: some View {
        CollectionEmojiTile(emoji: splitTitle.emoji ?? Self.defaultEmoji)
            .accessibilityHidden(true)
    }

    /// Splits the leading emoji off a collection title so it can be shown as the row's icon tile.
    static func firstEmoji(inTitle title: String) -> (emoji: String?, title: String) {
        let scalars = Array(title.unicodeScalars)
        var index = 0
        while index < scalars.count, scalars[index].properties.isWhitespace { index += 1 }

        var run: [Unicode.Scalar] = []
        while index < scalars.count {
            guard let scalar = isEmojiScalar(scalars[index], at: index, in: scalars) else { break }
            run.append(scalar)
            index += 1
        }

        guard !run.isEmpty else { return (nil, title) }
        let remainder = String(String.UnicodeScalarView(scalars[index...]))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (String(String.UnicodeScalarView(run)), remainder)
    }

    private static func isEmojiScalar(_ scalar: Unicode.Scalar, at index: Int, in scalars: [Unicode.Scalar]) -> Unicode.Scalar? {
        // variation selector / zero-width joiner keep a sequence together
        if scalar == "\u{FE0F}" || scalar == "\u{200D}" {
            return scalar
        }
        // regional indicators make up flag emoji
        if scalar.value >= 0x1F1E6 && scalar.value <= 0x1F1FF {
            return scalar
        }
        // default-emoji-presentation scalars (most emoji)
        if scalar.properties.isEmojiPresentation {
            return scalar
        }
        // text-presentation emoji followed by VS16, e.g. heavy black heart
        if scalar.properties.isEmoji,
           index + 1 < scalars.count,
           scalars[index + 1] == "\u{FE0F}" {
            return scalar
        }
        // modifiers / continuation inside a ZWJ sequence
        if index > 0, scalars[index - 1] == "\u{200D}", scalar.properties.isEmoji {
            return scalar
        }
        return nil
    }

    /// The full title with any leading emoji (shown in the tile) stripped off.
    static func displayTitle(forTitle title: String) -> String {
        let split = firstEmoji(inTitle: title)
        return split.title.isEmpty ? title : split.title
    }
}

/// The emoji icon tile used by Directory collection rows and the collection hero header.
struct CollectionEmojiTile: View {
    let emoji: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3 * standardPadding)
                .fill(Color(uiColor: .secondarySystemBackground))
            Text(emoji)
                .font(.system(size: 2 * standardPadding))
        }
        .frame(width: 5 * standardPadding, height: 5 * standardPadding)
    }
}

