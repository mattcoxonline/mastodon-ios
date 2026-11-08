// Copyright © 2025 Mastodon gGmbH. All rights reserved.

import Foundation
import SwiftUI

/// Layout spacing scale — the single source of paddings and gaps.
struct Spacing {
    static let xs: CGFloat = 4      // hairline gaps, within-lockup offsets
    static let s: CGFloat = 8       // default: row gutters, inner card padding
    static let m: CGFloat = 12      // between related groups in a card
    static let l: CGFloat = 16      // default: card padding, section separation
    static let xl: CGFloat = 24     // between sections, generous block spacing
    static let xxl: CGFloat = 32    // page-level breathing room
}

/// Corner radius scale for cards, tiles and controls.
struct Radius {
    static let xs: CGFloat = 4      // chips, mini controls, inner elements
    static let s: CGFloat = 8       // tiles, small cards
    static let m: CGFloat = 12      // standard cards
    static let l: CGFloat = 16      // large cards, sheets
    static let xl: CGFloat = 24     // hero cards, overlays
    static let pill: CGFloat = 999  // capsule buttons
}

let spacingBetweenGutterAndContent: CGFloat = Spacing.s

let maxFeedContentWidth: CGFloat = 700

struct ButtonPadding {
    static var vertical: CGFloat = 3
    static var horizontal = Spacing.s
    static var capsuleHorizontal: CGFloat = Spacing.l
}

struct PollPadding {
    static var optionPadding: CGFloat = Spacing.m
}

extension HorizontalAlignment {
    enum GutterAlign: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[.leading]
        }
    }
    
    static let gutterAlign = HorizontalAlignment(GutterAlign.self)
}

extension Color {
    static var dimmingBackground = Color.black.opacity(0.6)
}
