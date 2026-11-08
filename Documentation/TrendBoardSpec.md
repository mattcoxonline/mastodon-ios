# Explore › Hashtags — Trend Board (Concept A) implementation spec

Replace the flat trending-tag list with a ranked **Trend Board**: rank
numbers, honest per-day stats, rank-movement chips, 7-day sparklines, a
Today / This Week ranking toggle, and inline follow buttons. Everything is
computed client-side from `Mastodon.Entity.Tag.history`; no server changes.

Grounded in `Documentation/HashtagsRedesignConcepts.html` (Concept A).

## Current state

- `DiscoveryFeedsView` renders all three Explore tabs through
  `TimelineListView` with `timeline: .discover(.hashtags)`.
- `TimelineFeedLoader` case `.hashtags` fetches `APIService.shared.trendHashtags`
  and maps tags to `TimelineItem.hashtag(HashtagRowViewModel)`.
- `HashtagRowView` (used by that timeline) shows: name, "N people talking",
  sparkline (`WrappedLineChartView`), no rank / no follow / no movement.
- `HashtagHeaderView` (hashtag page header) already contains the exact stat
  math and the follow/unfollow pipeline to copy from.

## Non-goals (v1)

- **No "From people here" local/federated split** — no honest client-side
  signal for "used by local accounts" yet; revisit with the Pulse (Concept C)
  aggregation later.
- **No server/API changes.**
- The `TimelineFeedLoader` `.hashtags` branch becomes unused by Explore but
  stays in the codebase (cheap reversibility, still reachable by nothing else).

## New UI

`TrendBoardView` replaces the timeline when Explore's `.hashtags` tab is
selected (swap in `DiscoveryFeedsView.body`; the other two tabs are
unchanged).

```
┌───────────────────────────────────────────┐
│  Hashtags            (nav title, existing) │
│  [ Today │ This Week ]                    │  ← segmented, re-sorts
│                                           │
│   1  #oslo        ▁▂▃▅▆▇   [ Follow ]      │  ← rank, name, spark, action
│      312 posts · 89 participants   ↑2     │
│   2  #oslopride   ▁▁▂▆▇▇   [ Following ]  │
│      188 posts · 54 participants   new    │
│   3  …                                    │
└───────────────────────────────────────────┘
```

Row anatomy (HStack, `Spacing.m` gaps, row padding `Spacing.l` horizontal):
1. **Rank** — 1…N in current mode order, `.title2`-weight bold, secondary
   color; top three rows tint accent.
2. **Info stack** — tag name `#…` (headline weight); caption below:
   `<posts> posts · <people> participants` using the existing
   `Scene.FollowedTags.Header.Posts/Participants` labels and
   `MastodonMetricFormatter`; plus a movement chip where applicable
   (Today mode only): `↑N` (rank rose vs yesterday), `↓N` (fell), `new`
   (no activity in earlier buckets). Chips: green tint up, red tint down,
   neutral fill for new.
3. **Sparkline** — reuse `WrappedLineChartView` (50×26, accounts per day,
   `accessibilityHidden`).
4. **Follow button** — replicate `HashtagHeaderView`'s pipeline exactly
   (followTag / unfollowTag via APIService, update local state from the
   response; `.updating` visual state while in flight). Follow state comes
   from `Tag.following`; after a successful action, replace the tag in the
   model's array (do not rely on FeedCoordinator for this list).

- Row tap → `navigator.push(.timeline(.hashtag(tag, includeHeader: true)))`.
- `.refreshable` on the scroll view re-fetches.
- States: `ProgressView` while loading; error text + retry button on
  failure; "Nothing trending right now" empty state.

## Ranking & movement (pure functions — unit-test these)

Let `history` be the tag's buckets **sorted by `day` ascending** where
`uses`/`accounts` are numeric strings:

- `postsToday(tag)` = uses of the newest bucket (matches HashtagHeaderView's
  `postsToday`).
- `postsWeek(tag)` = sum of all buckets' uses.
- `peopleToday(tag)` = accounts of the newest bucket.

Mode sorting:
- Today: descending `postsToday`; ties broken by name.
- This Week: descending `postsWeek`; ties by name.

Movement (Today mode only), computed within the fetched set:
- `yesterdayKey(tag)` = uses of the second-newest bucket.
- Rank the set by `postsToday` (1 = top) and by `yesterdayKey` (1 = top,
  tags with zero/nonexistent yesterday bucket rank last).
- chip = `yesterdayRank - todayRank`: positive → `↑N`, negative → `↓N`,
  zero → no chip. If every bucket older than today is zero-valued or the
  tag has only one bucket → `new`.

## Strings (new keys, all four locales + en-US via catalog edit)

| key | en | nb | pl | uk | ar |
|---|---|---|---|---|---|
| `Scene.Discovery.TrendBoard.Today` | Today | I dag | Dzisiaj | Сьогодні | اليوم |
| `Scene.Discovery.TrendBoard.ThisWeek` | This Week | Denne uken | W tym tygodniu | Цього тижня | هذا الأسبوع |
| `Scene.Discovery.TrendBoard.New` | New | Ny | Nowość | Нове | جديد |
| `Scene.Discovery.TrendBoard.NothingTrending` | Nothing trending right now | Ingenting er populært akkurat nå | Nic nie jest teraz modne | Зараз нічого популярного | لا شيء رائج الآن |

- nb goes in via `scripts/add_nb.py` batch (`scripts/nb_translations/batch4.json`).
- en/en-US/pl/uk/ar go in via a format-preserving catalog edit
  (serialize + round-trip guard from `prune_localizations`).
- **Manual entries in `Generated/Strings.swift`** are required for each new
  key (SwiftGen does not manage L10n) — add a `TrendBoard` namespace under
  `Scene.Discovery` with comments, same style as neighboring entries.
- If `Scene.FollowedTags.Header.Posts/Participants` lack nb entries, add
  "innlegg" / "deltakere" to the same batch.

## Files

| action | file |
|---|---|
| create | `Mastodon/In Progress New Layout and Datamodel/Discovery/TrendBoardView.swift` (view + `@Observable TrendBoardViewModel`) |
| modify | `Mastodon/In Progress New Layout and Datamodel/DiscoveryFeedsView.swift` — `.hashtags` branch renders `TrendBoardView()` |
| modify | `Mastodon/In Progress New Layout and Datamodel/Discovery/TrendBoardView` **must be added to the pbxproj membershipExceptions list** (`PBXFileSystemSynchronizedBuildFileExceptionSet FBBEA04F…`, target Mastodon) — new files in "In Progress New Layout and Datamodel" are opt-in and silently don't compile otherwise |
| modify | `MastodonSDK/…/Localizable.xcstrings` (+nb batch) and `Generated/Strings.swift` |
| create | `MastodonTests/TrendBoardTests.swift` |

## Tests (`MastodonTests/TrendBoardTests.swift`)

Fixtures: build `Mastodon.Entity.Tag`s by decoding small JSON payloads
(strings for `day`/`uses`/`accounts`, like the streaming tests). Cover:

1. today ranking (desc, tie by name)
2. week ranking (uses summed across buckets)
3. movement delta: tag rising → `↑N` where N == yesterdayRank − todayRank
4. `new` when only one bucket / older buckets all zero
5. zero history → last place, no crash
6. caption counts: postsToday/week/people correctness

## Verification checklist

1. Build (simulator destination) — SUCCEEDED.
2. `xcodebuild test -only-testing:MastodonTests/TrendBoardTests` — all pass.
3. Install + launch on logged-in sim, screenshot Explore › Hashtags: verify
   rank numbers, chips, sparklines, segmented control visible via pixel
   analysis; exercise Today ↔ This Week toggle in Xcode GUI.
4. Commit + push; update notes.md/changelog.md.
