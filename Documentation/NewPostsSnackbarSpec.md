# New-Posts Snackbar: Centered Liquid Glass Pill — Design Spec

**Status:** IMPLEMENTED (all four decision points per recommendation: D1
neutral `.regular` glass with adaptive labels, D2 coverage unchanged,
D3 DEBUG `-UITestSnackbarDemo` launch arg + UI test, D4 slide+fade
transition). All three Snackbar variants restyled; pill top-center below
the header; `onTapGesture` → real Buttons with 44pt tap targets
(VoiceOver now announces "2 new, button"). Verification: UI test passed
(pill midX within 0.3pt of window center; 44pt target) and pixel-checked —
soft blurred glass edges, adaptive dark text, ~32pt visual capsule on the
demo screenshot. Demo-mode flag keeps the merge pipeline from zero-ing
the demo count (initial-load race found by the first failing run).
TabBarSmokeTests suite green (8 pass + 1 designed skip).
**Request (user):** The home feed's "N new" indicator (appears top-right below
the header when the background refresh/streaming delivers new posts) should
keep its behaviour, but be restyled as a proper Liquid Glass element, sized
to the system's glass scale, and repositioned to sit at the TOP of the view,
directly below the header, horizontally CENTERED.

**Resulting layout:**

```
┌──────────────────────────────────────────────┐
│              [ Following  ˅ ]               │  ← nav header (feed picker)
│                                              │
│              ╭─────────────╮                │
│              │ ⌃  2 new     │                │  ← glass pill, centered
│              ╰─────────────╯                │
│         (rest of the timeline feed)          │
```

---

## 1. How it works today (investigated)

All in `Mastodon/In Progress New Layout and Datamodel/Timeline/TimelineListView.swift`:

- **Placement** (line ~303): the snackbar is an overlay on the whole timeline
  ZStack:
  `VStack(alignment: .trailing) { [conditional Snackbar] Spacer().frame(maxWidth/maxHeight: .infinity) }.padding(Spacing.xs)`
  — the `Spacer` pushes the pill to the top, `alignment: .trailing` pins it to
  the **top-right**, 4pt inset. (The ZStack respects safe areas, which is why
  it already reads "just below the header".)
- **The `Snackbar` view** (line ~1258): white footnote text (+ `chevron.up`
  icon for the new-items variant) on a **solid accent-green `Capsule()`
  fill** — a flat tinted pill, not glass. Padding is xs vertical / s horizontal.
- **Three variants share the one component** (mutually exclusive via if/else):
  | Variant | Shows | Where it actually appears |
  |---|---|---|
  | `.newUnreadItems(count)` | "2 new" + ⌃ | gated by `canDisplayNewItemsSnackbar`: **home feed + Mentions page** (both notification scopes) |
  | `.asyncRefreshUpdateAvailable` | "Show more replies" | timelines whose search returned partial results |
  | `.asyncRefreshUpdateFetching` | spinner (text hidden) | while those async results load |
- **Behaviour**: tap → `viewModel.scrollToTop()`; the count self-heals as
  you scroll up past new items (`unseenNewItemsCount` tracks the scroll
  anchor). Streaming inserts and background refreshes both feed the counter
  via the merge pipeline — none of that changes.
- **A11y gap**: the pill is a plain view + `onTapGesture` — VoiceOver does
  not announce it as an actionable element.
- No UI tests touch the snackbar. The string is shared key
  `Common.Controls.Timeline.Loader.UnreadItemsButtonTitle` ("%(unreadCount)lld new")
  — no string changes needed.

### Repo precedents (Day 6 lessons, Applied directly here)

- `glassEffectIfAvailable(_:withTint:in:)` (house helper,
  `GlassEffectIfAvailable.swift`) renders `.glassEffect` on iOS 26+,
  colour-fill fallback pre-26. Verified in the profile toolbar work.
- iOS 26 glass capsule scale, measured from our own toolbars: content controls
  render ~34-44pt tall capsules with subheadline text.

---

## 2. Proposed design

### 2.1 Position — top, centered

- Overlay `VStack(alignment: .trailing)` → **`alignment: .center`** (keep the
  `Spacer`-to-top construction; the pill stays below the safe area = below
  the nav header).
- Inset: top `Spacing.s` (8pt) — slightly more breathing room under the
  header than today's 4pt; keep ZigZag-free horizontal inset (centering makes
  it moot).

### 2.2 Styling — Liquid Glass, all three variants

- Replace `Capsule().fill(accent)` + white text with the house modifier:
  `.glassEffectIfAvailable(.regular(interactive: true), in: .capsule)`.
- Label colours become adaptive (`.primary`) so the pill reads correctly over
  any feed content — white text stays only in the pre-26 fallback.
- **Pre-iOS-26 fallback**: status quo look (accent capsule + white text) via
  an explicit `if #unavailable(iOS 26)` background branch. The helper's
  `withTint:` parameter is NOT used — it would tint the *glass itself* on 26,
  but we want neutral glass there (decision point D1).
- Fetching variant: `ProgressView` tint reverts to default (adapts to glass).

### 2.3 Sizing — glass scale

- Font `.footnote` → **`.subheadline`**; padding `Spacing.s` on both axes
  → effective capsule ≈ 32pt tall — matching the glass control scale of the
  nav buttons, vs today's ~24pt tinted lozenge.
- Tap target: 44pt minimum hit height via `.contentShape(Rectangle())` on an
  expanded frame (visual stays ~32pt).

### 2.4 Semantics + motion (recommended small fixes while in here)

- Convert `onTapGesture { scrollToTop() }` overlays into a `Button` so
  VoiceOver announces "2 new, button".
- Insertion/removal animation: `.transition(.move(edge: .top).combined(with:
  .opacity))` keyed on count/state — today the pill pops in with no motion
  (optional, decision point D4).

### 2.5 Explicitly NOT changing

- The count logic, merge pipeline, streaming integration, self-heal on scroll,
  tap-to-top behaviour, feed gating (`canDisplayNewItemsSnackbar` stays
  home + notifications; Oslo/Everything never had this pill — noted as a
  possible follow-up, decision point D2).
- The donation banner sharing the overlay (bottom-aligned; no interaction).

---

## 3. Localization / a11y

- Zero new strings (existing plural key covers count text).
- A11y: the Button conversion (§2.4) is the only semantic change.

## 4. Verification plan

1. Build green; full TabBarSmokeTests regression.
2. **Deterministic test** (recommended, D3): DEBUG-only launch argument
   `-UITestSnackbarDemo` handled in `TimelineListViewModel` — sets
   `unseenNewItemsCount = 2` on the home timeline after initial load. New UI
   test asserts the pill exists, then screenshots are pixel-checked:
   horizontal centroid within ±8pt of screen center; glass edge signature
   (bright-blob-vs-backdrop step like the toolbar measurements); capsule
   height ≈ 32pt (±4pt).
3. Manual eyeball in Xcode GUI: real "N new" appearance at top-center on the
   home feed while scrolled down, tap → jumps to top.

## 5. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Center pill collides with nothing at top-center — but the Feed page shares nothing there (nav has the picker only) | None | — |
| Glass pill unreadable over very busy feed cells | Low | `.regular` glass + `.primary` text is the system standard for exactly this case; eyeball over photo-heavy sections |
| The async-refresh variants appear in Explore/search flows — restyle travels there too | None (intended) | Same component, same design |
| Button conversion changes hit-testing under fast scrolling | Very low | Tap target only grows |

## 6. Decision points (need your call before implementation)

- **D1 — Glass tint**: (a) neutral `.regular` glass, adaptive label
  (recommended — the system look, matches nav glass; accent signal dies with
  the old fill) vs (b) accent-tinted glass (brand green glass, one-line
  change via `withTint:`, pre-26 fallback comes free).
- **D2 — Coverage unchanged**: the Oslo tab and Everything feed keep their
  current behaviour (no pill — new posts just arrive on next visit/refresh).
  Extend it there too, or leave? (recommend: leave for now, separate change).
- **D3 — DEBUG launch-arg demo hook + UI test** so the pill is verifiable and
  regression-protected (recommended; small, follows the house
  `-UITestInstrumentation` pattern from the compose-flake plan).
- **D4 — Appear/disappear animation** (subtle slide+fade, recommended) vs
  keep the current instant pop.

## 7. Implementation plan (~1-1.5h incl. test hook)

1. `Snackbar` view: glass styling + sizing + Button semantics (TimelineListView.swift).
2. Overlay alignment → center, top inset; transitions if D4.
3. Optional DEBUG launch-arg hook in `TimelineListViewModel` (D3).
4. UI test + pixel verification; suite regression; commit.

**Files touched: 1-2, all existing** (`TimelineListView.swift`, optionally
`TimelineListViewModel.swift`, test in `TabBarSmokeTests.swift`).
