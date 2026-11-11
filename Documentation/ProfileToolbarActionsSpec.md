# Profile Page: Action Buttons to the Nav Bar — Design Spec

**Status:** spec for review — no code written yet
**Request (user):** The profile page's primary action ("Edit profile" on your own
profile; "Follow"/"Unfollow" etc. on others) and the overflow menu (ellipsis icon)
are currently inline in the header and awkwardly duplicated as a bottom-pinned bar.
Rework both controls as proper Liquid Glass toolbar items, pinned to the TOP-RIGHT
of the screen, opposite the existing back arrow.

**Resulting layout:**

```
┌──────────────────────────────────────────────┐
│ [←]                          [Follow] [ ⋯ ]  │   ← nav bar (over the banner)
│          banner image (edge to edge)         │
│   ┌────┐                                     │
│   │avatar│   Display Name                     │
│   └────┘   @handle                            │
│             stats · bio · fields              │
│  ──────────────── pages ─────────────────    │
│             (posts / media / featured)        │
└──────────────────────────────────────────────┘
```

---

## 1. How it works today (investigated)

All in `Mastodon/In Progress New Layout and Datamodel/Profile/ProfileView.swift`:

- **`ProfileActionBar` is rendered TWICE** (this is the "inline but also sticky"
  feeling):
  1. **Embedded copy** — inline in the scroll content, between the bio/fields
     block and the page selector (line 60).
  2. **Floating copy** — a second instance pinned near the bottom of the screen
     in a ZStack overlay (line 100).
- The two copies cross-fade via a `VerticalPositionKey` PreferenceKey: as you
  scroll, when the embedded copy reaches the floating copy's position, the
  floating one fades out and the embedded one fades in (opacity swap at line 68
  and the `onPreferenceChange` handler at line 116). A `matchedGeometryEffect`
  (`profileActionBarAnimationNamespace`) pretends it's one morphing bar.
- **Contents** (both copies, identical):
  - Primary relationship button — `RelationshipButtonType.largeButton()`, full
    width, `CapsuleButtonStyle` (solid fills: prominent = green + white text,
    subtle = grey, neutral = translucent).
  - `ActionBarMenuButton` — a SwiftUI `Menu` with an ellipsis icon in a 48pt
    circle. Menu items are built by
    `relationshipViewModel.profileMenuActions(account:relationship:)` (share,
    mute, block, report, open in browser, follow-lists, etc.).
- The nav bar itself is bare: standard back arrow from the NavigationStack,
  `.toolbarBackgroundVisibility(.hidden, for: .navigationBar)` keeps the banner
  scrolling edge-to-edge underneath. **No trailing toolbar items exist on the
  profile today.**
- Label text comes from `RelationshipButtonType.buttonText(isLarge:)` — it has a
  short ("longForm: false") and a long variant for some states (e.g. follow
  request).

### Repo precedents for top-trailing Liquid Glass buttons (established pattern)

Plain SwiftUI toolbar buttons get Liquid Glass rendering by the system on
iOS 26 — we already use this in four places:

| Surface | Pattern |
|---|---|
| Explore search button (`ExploreRootView.swift:28`) | `ToolbarItem(.topBarTrailing)` + plain `Button` ≝ glass capsule |
| Mentions filter button (`MastodonMainTabView.swift:332`) | same |
| You screen settings gear (`ProfileMainMenuView.swift:39`) | same |
| Collections "+" button (`TimelineListView.swift:610`) | plain `Button` + `.prominentCircle(diameter: 40)` + `.sharedBackgroundVisibilityHidden()` |

We also already have the iOS-26 gating helper
`glassButtonStyleIfAvailable(prominent:)` (`GlassEffectIfAvailable.swift`):
`.glassProminent` / `.glass` on iOS 26+, `.borderedProminent` / `.bordered`
fallback for the 18.6 floor.

### Dead code found while investigating (leave or sweep — decides at review)

- `ProfileViewModel.navigationButtons` (ProfileViewModel.swift:69) — builds
  `UIBarButtonItem`s (gear, hash, bookmark, heart, share / ellipsis, reply) all
  with `action: nil`. **Referenced nowhere.** Vestige of an earlier UIKit-hosted
  header attempt. Recommend deleting in the same change.

---

## 2. Proposed design

### 2.1 New toolbar component

Add to `ProfileView.swift` (same file — no new file, so no pbxproj
membershipExceptions chore):

```
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        profileRelationshipButton          // "Follow" / "Edit profile" / …
    }
    ToolbarItem(placement: .topBarTrailing) {
        ProfileToolbarOverflowMenu()        // ellipsis Menu
    }
}
```

- **Primary button**: text label in a glass capsule. Use the SHORT label form
  (`buttonText(isLarge: false)`) so nav-bar space never forces truncation
  (nb "Følg", en "Follow" — all short forms are single words except
  "Requested→Cancel request", which still fits at one line).
- **Prominence mapping** (replaces today's green/grey CapsuleButtonStyle):

  | Relationship state | Old style | New top-bar style |
  |---|---|---|
  | Follow / Follow back / Request to follow | prominent (green solid) | `.glassProminent` (accent-tinted glass — visually the "primary CTA") |
  | Approve follow request¹ | prominent | `.glassProminent` |
  | Unfollow / Requested (cancel) / Unmute / Unblock | subtle (grey solid) | `.glass` (neutral glass) |
  | Edit profile (own profile) | prominent (green solid) | `.glass` |
  | "Show anyway" (moderator-hidden content) | neutral | `.glass` |
  | Updating (in-flight) | spinner in capsule | `ProgressView()` inside the same slot |
  | Error | exclamation icon | exclamation icon in a plain glass capsule |

  ¹ The banner's Accept/Reject follow-request buttons (someone requesting to
  follow YOU) stay where they are — see §4, out of scope.

  Note: "Edit profile" suggested neutral rather than prominent: in the top bar
  it is a navigation affordance, not a conversion CTA, and the accent tint stays
  reserved for actual relationship actions. (Decision point D2.)

- **Overflow menu**: `Menu` with `Image(systemName: "ellipsis")`, plain toolbar
  button (system glass circle, same as today's icon). **Menu item construction
  moves verbatim** from `ActionBarMenuButton` into the new
  `ProfileToolbarOverflowMenu` — zero behavioural change to any menu action
  (share/mute/block/report/navigate streaks continue to work identically).

- **Glass grouping**: two separate `ToolbarItem`s with
  `.sharedBackgroundVisibilityHidden()` each — matching the collections "+"
  precedent — so each control gets its own capsule rather than merging into one
  shared glass container. (Decision point D3, visual.)

### 2.2 Removal list (all in ProfileView.swift)

| Remove | Why |
|---|---|
| Embedded `ProfileActionBar()` + its geometry-preference background (lines 60–74) | Replaced by the toolbar |
| Floating `ProfileActionBar()` copy + overlay VStack (lines 98–108) | Replaced by the toolbar (fully sticky now, by construction) |
| `VerticalPositionKey` PreferenceKey struct + both `.background(GeometryReader…)` probes | Existed only for the crossfade |
| `@State embeddedActionBarHasCaughtUpToFloatingActionBar` + `onPreferenceChange` handler | Same |
| `@State isPresentingActivityFilter`, `@Namespace profileActionBarAnimationNamespace`, `matchedGeometryEffect` usage | Now unreferenced |
| `ProfileActionBar` struct + nested `ActionBarMenuButton` (body at line 886+) | Contents move to the toolbar component |

**Keep:** `nestedScrollViewModel` and `NestedScrollViews.swift` untouched —
`innerScrollDisabled` is the page/timeline scroll coupling, only the one
opacity-condition read goes away with the bar.

**Net effect:** ~90 lines of crossfade machinery deleted; the buttons become
genuinely sticky (in the nav bar) instead of a two-copies illusion.

### 2.3 Header spacing after removal

- Bio/fields block now flows straight into the page selector: the
  `Spacing.l` spacers that previously bracketed the action bar collapse into a
  single `Spacing.l` gap (design tokens per the Day-5 spacing system).
- Nothing else in the header changes — banner, avatar lockup, stats, personal
  note, badges untouched. On own profile, banner/avatar camera edit buttons
  (edit mode only) are unaffected — they live in the banner, not the action bar.

### 2.4 Pre-iOS-26 appearance

`glassButtonStyleIfAvailable` falls back to `.borderedProminent` /
`.bordered`, which read fine in the nav bar on the 18.6 floor. The Menu is a
plain toolbar Menu on both. No `#available` branches needed at call sites.

---

## 3. Localization / a11y

- **Zero changes to existing strings**: every state already has localized text
  (en/nb/pl/uk/ar) via `L10nLookup`.
- **No new files**, therefore no pbxproj edit, no SwiftGen run.
- **Menu a11y label**: today's `ActionBarMenuButton` relies on the raw SF symbol
  description ("ellipsis"). Add a proper label — 1 new key:
  - Key: `Common.Controls.Actions.moreActions`
  - en "More actions" · nb "Flere handlinger" · pl "Więcej działań" ·
    uk "Більше дій" · ar "المزيد من الإجراءات"
  - Requires manual entry in `Localizable.xcstrings` (all 5 locales) AND the
    hand-maintained `Generated/Strings.swift` (house rule: L10n keys are not
    SwiftGen'd).
- The primary button keeps its visible text label → no a11y regression; toolbar
  order puts [primary][overflow] after the back arrow, matching visual order
  for VoiceOver.

---

## 4. Out of scope (explicitly not changing)

- **Follow-request Accept/Reject buttons** on the banner (shown on profiles of
  people awaiting YOUR approval) — they belong with their contextual message
  ("X requested to follow you"), stay in the banner.
- **Banner/avatar edit camera buttons** (edit mode).
- Page selector (Posts/Media/Featured) glass pills.
- Any menu action behaviour (mute/block/report/share logic unchanged).

---

## 5. Verification plan

1. **Build** green (Debug, simulator).
2. **States eyeball** in simulator: own profile (Edit profile), someone you
   follow (Unfollow), someone you don't (Follow — prominent), locked account
   (Request), in-flight (Updating spinner during action).
3. **Menu smoke**: open each of the top-level menu groups, verify every action
   still routes (spot-check: Share sheet opens; Mute toggles and badge appears
   in header).
4. **UI test** (new, cheap — 2 asserts added to TabBarSmokeTests or a small
   ProfileSmokeTests):
   - Open own profile: assert nav-bar button "Edit profile" exists + ellipsis
     menu button exists.
   - Open another profile from Oslo tab: assert a relationship button exists.
   - House XCUITest caveat applies: match by label BEGINSWITH predicates on
     menus; toolbar buttons on the glass bar query fine via `app.buttons`.
5. **Screenshot pixel sanity** (optional): top-right glass capsules sit over the
   banner while at rest, no banner occlusion of avatar/stats after removing the
   inline bar.

---

## 6. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| iOS 26 groups the two trailing items into one shared glass container by default | Medium (expected) | `.sharedBackgroundVisibilityHidden()` per item, per the collections-button lesson; verify at build |
| Long localized labels clip in the nav bar (e.g. nb "Avbryt forespørsel") | Low | Use short label form + `.lineLimit(1)` + `.minimumScaleFactor(0.6)`; spot-check nb/ar screenshots |
| `editMe` push behaves differently from inside a toolbar item | Very low | `navigator.push(.editProfile(...))` is context-free; same call as today |
| Removing the floating bar changes the timeline-to-header scroll coupling perception | Low | `innerScrollDisabled` machinery untouched; only the action-bar opacity read goes away |
| Glass capsule over pale banners lowers contrast (`.glass` regular on white-ish banners) | Low-medium | `.glassProminent` for the primary CTA keeps contrast; eyeball with @themayor's banner + a white banner profile |

## 7. Decision points (need your call before implementation)

- **D1 — Follow button prominence**:
  (a) Accent-tinted glass (`.glassProminent`) for Follow/Follow-back/Request;
  neutral glass otherwise — *recommended*: keeps one eye-catching CTA, maps to
  today's green-vs-grey semantics.
  (b) All states neutral glass; semantics only in the label — most austere
  HIG reading.
- **D2 — Own profile's "Edit profile"**: neutral glass (recommended, §2.1) vs
  accent glass like today's green button.
- **D3 — Glass grouping**: two separate capsules (recommended; matches
  collections "+" precedent and Instagram-style "Follow⋯") vs one shared glass
  container holding both.
- **D4 — New a11y string for the overflow menu**: add `moreActions` (recommended,
  5 locales, tiny) vs keep the raw "ellipsis" symbol description.

## 8. Implementation plan (~1.5–2h)

1. Add toolbar component + prominence mapping in ProfileView.swift; delete
   `ProfileActionBar`, floating copy, and the crossfade machinery.
2. Move `ActionBarMenuButton` menu builder into `ProfileToolbarOverflowMenu`.
3. Collapse now-orphaned spacers; spacing pass over bio→pages seam.
4. Delete `ProfileViewModel.navigationButtons` dead code.
5. Add `moreActions` key (xcstrings ×5 + Generated/Strings.swift) if D4 approved.
6. Build + states eyeball + menu smoke + new UI test; commit.

**Files touched (expected 3, all existing):**
- `Mastodon/In Progress New Layout and Datamodel/Profile/ProfileView.swift`
- `Mastodon/In Progress New Layout and Datamodel/Profile/ProfileViewModel.swift` (dead code delete)
- `Mastodon/Resources/Localizable.xcstrings` + `…/Generated/Strings.swift` (D4)
- `MastodonUITests/…` (new smoke asserts)
