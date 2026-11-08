# Explore > Directory — Redesign Spec

Wireframe: `~/vibe/ot-md-assets/oslotown-wireframe-directory.png`
Companion to commits `35bb74038` (curator collections in Directory) and `892a1409f` (author line removed).

## 1. Current state

- **Explore > Directory** (`.discover(.forYou)`) fetches matt@oslo.town's collections
  (account resolved once via the lookup API, cached in `directoryCuratorAccountID`)
  and renders them as `TimelineItem.collection` rows — the same avatar-mosaic
  `CollectionRowView` used by You > Collections.
- Tab bar, Explore toolbar (segmented Popular | Directory) and search are unchanged
  by this spec.

## 2. Target layout (from wireframe)

```
Explore                                  [search]
┌─────────────┬─────────────┐
│  Popular    │  Directory  │  (segmented; Directory active)
└─────────────┴─────────────┘
FEATURED                        (small caption label)
┌──────────────────────────────────────┐
│ (avatar)  Display Name        [Follow]│
│           first line of bio…          │
│           N followers                 │
└──────────────────────────────────────┘
┌──┐
│🎨│ Collection title A                │
└──┘ N accounts
┌──┐
│📷│ Collection title B                │
└──┘ N accounts
…                                     (scrollable list)
```

Two changes to the feed content:

1. **Featured account card** at the top — one account pulled at random from one
   of the curator's collections.
2. **Collection rows** simplified to: emoji tile + title + account count
   (replaces the avatar-mosaic row in the Directory only).

## 3. Features

### 3.1 Featured account card

**Selection (in `TimelineFeedLoader`, `.forYou` branch):**

- After the collections fetch succeeds, pick a random collection with at least
  one `CollectionMember` that has an `account_id`, then pick a random member.
- Resolve the member to a full account with the existing
  `APIService.accountsInfo(userIDs:)`. No further API calls needed.
- Re-roll only when the Directory feed is fetched fresh (open or
  pull-to-refresh). Do not re-roll on background/async refresh or pagination,
  to avoid layout jumping under the user.

**Card behavior:**

- Follow button reuses the existing `RelationshipViewModel`/follow machinery the
  account rows use (`.relationship` style in `AccountRowControl`); reflects the
  actual relationship, including a Following state if already followed.
- Tap anywhere else on the card pushes the profile
  (`navigator.push(.profile(account:relationship:))`), same as account rows.
- Layout per wireframe: avatar left; text stack with display name (semibold),
  first line of the bio truncated with ellipsis (`.secondary`), follower count
  (caption, `.secondary`); Follow button right of the lockup.
- Bio text: `account.note` arrives as HTML — reuse the existing
  HTML-to-plain-text parsing off the main actor (the pattern from the You-screen
  fix), never parse inline in the row.

### 3.2 Collection rows (Directory only)

- 44–48pt rounded-square tile (cornerRadius ~12) with the collection's emoji,
  centered, ~26pt.
- Emoji is **derived from the collection title**: the first contiguous emoji run
  in the title (Unicode scalars with `isEmoji`/`isEmojiPresentation`) moves to
  the tile; the remaining title text (trimmed) becomes the row label. This lets
  the curator control tiles just by naming collections e.g. ` Oslo & Design`.
- No emoji in the title falls back to a default tile (e.g. "🗂") — also covers
  collections the curator hasn't emoji-tagged.
- Secondary caption stays the existing "N accounts"
  (`L10nLookup.Scene.Collections.numberOfAccounts`).
- Tap pushes the collection detail (existing route `.timeline(.collection(vm))`).
- `CollectionRowView` is untouched — You > Collections and the embedded
  post-card keep the current avatar-mosaic design.

## 4. Architecture

**New `TimelineItem` cases** (`TimelineFeedLoader.swift`):

```swift
case directoryFeatured(DirectoryFeaturedModel)   // id: "directoryFeatured-<accountID>"
case directoryCollection(CollectionViewModel)    // id: "directoryCollection-<id>"
```

- Add to the `id` switch like existing cases.
- Directory collection viewmodels must reuse the existing
  `collectionViewModels` cache so state (relationship updates etc.) is shared
  between Directory and You > Collections.

**`.forYou` fetch branch** becomes:

```
curator lookup (cached) -> collections fetch (cached viewmodels)
featured = try await buildFeatured(from: collections)   // nil-safe
newBatch = featured.map { [.directoryFeatured($0)] } ?? []
         + collectionViewModels.map { TimelineItem.directoryCollection($0) }
newBatchBottomLoad = .nothingMoreToLoad
```

**New files** (under `In Progress New Layout and Datamodel/`):

- `Discovery/DirectoryFeaturedCard.swift` — card view + `DirectoryFeaturedModel`
  (`@Observable`: wraps an `AccountRowViewModel`, plus the truncated bio line
  derived from `account.note`).
- `Discovery/DirectoryCollectionRow.swift` — emoji-tile row view, plus a shared
  `firstEmoji(in:) -> (emoji, remainingTitle)` helper (used for tile + label).

**Rendering** (`TimelineListView`): add switch arms for the two new cases
alongside `case .account` / `case .collection` with the directory row paddings.
The "FEATURED" caption is part of the featured item's own view (above the
card), so it scrolls with content, per wireframe.

**Strings**: `Featured` caption — new L10n entry (scene discovery), added to
`Generated/Strings.swift` by hand + the xcstrings/strings localization pattern
used in this repo (all ~51 locales; e.g. Norwegian "Utvalgt").

## 5. Edge cases

- Collections list empty (collections feature flag off, or empty): Directory
  shows the existing empty state; no featured card.
- Random member already followed by the viewer: card stays, button shows
  Following state. (Simple; no re-roll.)
- Collections with zero resolvable members / account fetch failure: featured is
  skipped silently rather than failing the whole feed.
- Account with no bio: the bio line is omitted; name + follower count remain.
- Feature flag for the whole section unchanged (`isAvailable(.collections)`).

## 6. Phases

1. Data plumbing: `TimelineItem` cases, featured model, loader changes, emoji
   extraction helper.
2. `DirectoryFeaturedCard` (avatar, name, bio line, followers, Follow).
3. `DirectoryCollectionRow` (emoji tile rows) + `TimelineListView` wiring.
4. Strings + localization sweep.
5. Build on iPhone 17 sim, side-by-side against the wireframe, polish spacing.

## 7. Open questions (spec defaults chosen)

- Emoji source: derived from collection title (curator controls it via naming).
  If you would rather keep titles emoji-free and pick tiles per collection in
  code, that's a small mapping dictionary instead.
- Featured re-rolls on every fresh Directory load (open/refresh), not persisted.
- Followed accounts are not excluded from being featured — the button just
  shows Following.
