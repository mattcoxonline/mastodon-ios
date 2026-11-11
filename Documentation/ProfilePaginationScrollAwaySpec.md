# Profile Pagination Tabs: Unstick and Scroll Away — Design Spec

**Status:** spec for review — no code written yet
**Request (user):** On profile pages, the Activity / Media / Featured tabs
stick to the top of the screen as you scroll and collide with the profile's
new nav-bar buttons. They should NOT be sticky — scroll away inline with the
rest of the page, like the banner and bio.

---

## 1. What actually happens today (investigated + measured)

The profile's sticky tabs are **sticky by construction, not by a pinning
API**. Layout in `ProfileView.swift`:

```
ScrollView (outer)                          ← .nestedScrollview(.outer)
  [banner+avatar] [bio/stats]               ← scroll away normally
  if !hideContent:
    VStack(spacing: 0)                      ← THE BLOCK
      [ProfilePaginationControl]            ← Activity | Media | Featured
      [Divider]
      [pages: the swipeable timelines]      ← .nestedScrollview(.inner) inside
    .frame(height: geo.size.height - 45)    ← ★ the culprit
```

- The pages block is deliberately sized **45pt shorter than the screen**.
  The outer scroll's maximum offset is therefore reached while the block's
  top still sits 45pt below the screen top — at that point the block's
  bottom is flush with the screen bottom and the pagination tabs rest at
  the very top, pinned, while the nested-scroll machinery hands gesture
  control to the inner timeline.
- **Probe measurements** (UI test with frame queries + screenshots, iPhone 17
  sim): the Activity segment rests at **y = 45pt** after any scroll and
  stays there across further swipes. The nav-bar header buttons float at
  y 67-101pt (measured "Edit Profile" at (210, 67, 106×34)). The pinned
  tabs at y 45-80 sit **inside the header button band** — the collision the
  user reported.
- The `45` constant carries the comment *"because the safeAreaInsets lie"*
  (the GeometryReader ignores vertical safe areas, so
  `geo.safeAreaInsets.top` reports 0). It reserves exactly one "pinned
  band" under the status bar on intent — a pre-nav-buttons-era design.
- The pagination control itself is a `GlassEffectContainer` of glass pills
  (iOS 26) spanning the full width — so when pinned, it also visually fights
  the glass capsules of the profile toolbar.

Nothing uses a `pinnedViews` API or any other UIKit pining — changing the
block's height is the whole mechanism.

## 2. Proposed change

**One line of layout arithmetic.** Size the block taller than the screen so
the outer scroll can push the pagination + divider fully past the top edge
before the nested-scroll handoff:

```swift
.frame(height: geo.size.height + paginationScrollAwaySlack)
```

- Block top's rest position at maximum outer scroll = screen height − block
  height = **−slack pt**. For the pagination (~44pt) + divider to be fully
  off-screen the slack must be ≥ ~46pt; use **100pt** for comfortable
  margin under dynamic type (see §4 R1).
- Remove the stale comment; the `- 45` disappears entirely.
- **No logic changes**: the nested scroll handoff (outer ↔ inner, top/bottom
  direction switching in `NestedScrollViews.swift`) is geometry-driven
  ("reached bottom of outer → enable inner") and is untouched. Pagination
  segments still switch pages while visible.
- Consequences, all intended:
  - The tabs scroll away with the bio; reading the timeline at full scroll
    shows only the timeline — same visual semantics as Instagram/Threads
    profiles without a pinned sub-header.
  - The inner timeline pages gain ~45pt of visible height at full scroll
    (the old reserved band becomes content).
  - The inner timeline's top edge extends under the status bar edge like
    every other feed in the app (currently it stops 45pt short of top).

### Explicitly NOT changing

- The nested-scrollview two-phase scrolling itself (banner-scroll-then-
  timeline-scroll remains; pull-down at the top of the timeline still
  hands back to the outer scroll and re-reveals the header).
- The pagination control's glass pill styling, page switching, Featured-page
  availability gating.
- The floating tab bar / FAB overlays (outside this view).

## 3. Edge cases / risks

| # | Case | Assessment |
|---|---|---|
| R1 | Dynamic Type / larger pagination height | Slack 100pt ≥ pagination (~44) + divider + band; even a much taller pill row clears. Slack only needs to exceed the PaginationControl height, and overshoot is invisible (content simply extends under the top edge). |
| R2 | Profiles with NO Featured page (`pagesToShow.count == 1`) — block contains only the pages | Today they rest 45pt short at max scroll; with the fix the timeline goes edge-to-top. Improvement, no behavior change. |
| R3 | Boosts/replies filter pill (`fixedHeader` inside the inner timeline, shown on profile Activity pages) | It lives at the top of each page's inner region. After the change it sits ~-55pt at full scroll — reachable by scrolling back up, consistent with "everything in the header area scrolls away." Note for review: if you want that filter reachable while deep in the feed, that would be a separate change. |
| R4 | Suspended/hidden profiles (block absent) | Unchanged. |
| R5 | inner-timeline pull-down handback (scroll up in feed → outer scroll resumes, header reappears) | Untouched mechanics; verified in regression. |

## 4. Verification plan

1. Build; probe test (already prototyped during investigation) formalized as
   `testProfilePaginationScrollsAway`: open own profile → assert the
   Activity segment exists near rest → swipe up repeatedly → assert
   `activity.frame.maxY <= 0` (fully past the top edge) → swipe down →
   assert it reappears.
2. Screenshot pixel-check at full scroll: no pagination pills anywhere in
   the top 120pt band; timeline rows render under the status bar edge.
3. Full TabBarSmokeTests regression.

## 5. Decision points

- **D1 — Approach**: (a) unstick via block resize as specced (recommended;
  one line, matches your ask) vs (b) keep pinned but rest BELOW the nav bar
  (reserve ~120pt instead of 45 — keeps stickiness, renames the collision;
  not what you asked for).
- **D2 — Slack constant**: 100pt (recommended) vs computed-from-content
  (messier for zero user-visible difference).

## 6. Implementation plan (< 1h)

1. `ProfileView.swift`: block frame → `geo.size.height + 100`, delete the
   stale comment.
2. Turn the probe test into the real regression test (swipe-away assert).
3. Build, probe/pixel verify, full suite; commit.

**Files touched: 1-2, all existing** (`ProfileView.swift`,
`TabBarSmokeTests.swift`).
