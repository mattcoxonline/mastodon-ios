# Spec — "Make It Rain" oslo.town Easter Egg

*Status: SPEC ONLY, not implemented · drafted 2026-11-09 against `oslo-reskin` @ 777742155 ·
house spec-first convention (cf. TrendBoardSpec.md, DirectoryRedesignSpec.md)*

## 1. Summary

A hidden easter egg: tapping the **Oslo tab icon** (the oslo.town brand mark) rapidly — or
long-pressing it, whichever proves reliable on iOS 26 — makes the app "rain" a celebratory
shower of emoji: 🏳️‍🌈 (rainbow pride flag), 🏳️‍⚧️ (trans pride flag), and 🇳🇴 (Norwegian flag).
Short, cheap, delightful, invisible to anyone who doesn't know it exists.

## 2. Goals / non-goals

**Goals**
- Trigger discoverable only by accident or by word of mouth; zero UI clutter, zero settings, zero docs in-app.
- Zero interference with normal use: the rain overlay never blocks touches, never appears during normal navigation, self-dismisses.
- Fully local: no server calls, no analytics, no persistence, no L10n surface (except one optional a11y string, see §7).
- Respects accessibility (Reduce Motion) and VoiceOver users can trigger it too via a custom a11y action.

**Non-goals (explicitly out of scope)**
- No sound effects; no confetti physics engine; no third-party particle library; no persistence of "unlock" state; no App Store review notes; no additional trigger surfaces beyond the ones specced; no parades.

## 3. Trigger spec

| Property | Value | Rationale |
|---|---|---|
| Primary trigger | **5 rapid taps** on the Oslo tab icon within a 2.0s sliding window | Multi-tap is the classic hidden-gesture convention; a long-press on a tab item risks colliding with platform reserved behaviors (reorder menus, context menus in some tab styles) |
| Alternate (if spike proves multi-tap unobservable) | **Long-press ≥ 1.2s** on the same icon | Detectable even when the system swallows repeated taps on the selected tab |
| Cooldown | 15s after a successful trigger | Prevents accidental re-trigger while user is still on the tab |
| Reset | Tap window resets on any navigation event | Avoids counting taps spread across browsing |
| Feedback on trigger | Light haptic (`UIImpactFeedbackGenerator`, `.light`) at the 5th tap | Discreet confirmation; no system alert |
| Dismissal | Auto-dismiss after 4.0s; tapping anywhere does NOT dismiss (overlay is non-interactive) | Simplicity; the shower is short |

### 3.1 Tap-detection mechanics — THE OPEN TECHNICAL RISK

The tab bar is a SwiftUI `TabView` with custom labels:
`Tab(value: tab) { view(forTab: tab) … } label: { tab.label(isSelected: …) }`
(`MastodonMainTabView.swift` ~line 210). The known constraint from the Day-3 compose-tab
experiments: SwiftUI only **observes selection changes** — tapping the *already-selected*
tab (the common easter-egg flow: sit on Oslo, tap its icon 5×) may produce no observable
event, and `.onTapGesture` attached inside `tab.label` may be swallowed by the TabView
or may break tab selection entirely. This MUST be resolved by spike before committing
to the interaction.

**Spike (Phase 0)** — attach a debug tap-counter to the `.localFeed` tab label via
`simultaneousGesture` and log. Three outcomes:
- **A. Gestures register AND selection still works** → ship multi-tap on the tab icon (primary).
- **B. Gestures never register on the tab label** → fall to Trigger Ladder candidate L2.
- **C. Gestures register but break selection** → abandon label gestures; use L2.

**Trigger Ladder (fallback candidates, in order)**
- **L1 (primary):** multi-tap on the Oslo tab icon.
- **L2:** long-press on the **"oslo.town" segment** of the Oslo page scope picker (`Text("oslo.town")` in the `.title` `Picker`, `MastodonMainTabView.swift` ~line 373) via a `simultaneousGesture` — still "the oslo.town logo in the main navigation," visible on the Oslo page as the brand segment. Prototype in the same spike; picker segment text may swallow gestures like tabs do.
- **L3 (last resort, fully under our control):** 5 rapid taps on the **page-header area** of the Oslo local timeline — namely add an invisible, `accessibilityHidden` 44×44pt `Color.clear.contentShape(Rectangle())` overlay on the trailing edge of the Oslo nav bar (a hidden "logo hot corner"), placed via an existing toolbar slot. Acceptable but weakest discoverability story; only if L1 and L2 both fail.

> Phase 0 is a 30–45 min spike with a debug log — its outcome selects the trigger, and Phases 1–3 are unchanged either way.

## 4. Rain overlay spec

**Attachment point:** the same `.overlay` tree that hosts the Compose FAB on the whole
`TabView` (`MastodonMainTabView.swift` ~line 231: `.overlay(alignment: .bottomTrailing) …`).
Add a second overlay, `alignment: .top`:

```
.overlay(alignment: .top) {
    if tabViewRouter.isPrideRainActive {
        PrideRainView()
            .allowsHitTesting(false)          // never blocks interaction
            .transition(.opacity)
            .zIndex(99)
    }
}
```

**`PrideRainView` mechanics (pure SwiftUI, no dependencies, no TimelineView scroll-hitch risk):**

| Property | Spec |
|---|---|
| Particle count | 60 (fixed — deterministic enough for tests, light on GPU) |
| Emoji pool | `"🏳️‍🌈", "🏳️‍⚧️", "🇳🇴"` — equal thirds (20 each) |
| Source | Top edge, x pseudo-random across 0…1, y = -0.1 screen heights |
| Motion | Per-particle: fall speed 380…760 pt/s, slight sinusoidal sway (amplitude 6–14pt, period 0.9–2.2s, phase per particle), rotation ±20°..±35° % degrees over the fall, all from a seeded PRNG per launch of the effect (seed = trigger timestamp) |
| Size range | 22pt … 40pt font sizes (big enough to read, small enough to feel like a shower, not a wall of emoji) |
| Opacity | Fade in first 0.3s; particles spawn staggered 0–0.8s; whole layer fades 3.5s→4.0s |
| Duration | 4.0s from trigger, then `isPrideRainActive = false` (router owns dismissal task) |
| Clock | `TimelineView(.animation)` driving all particles from a single `Date` — ONE invalidation source, positions computed per particle from the start time; no `CADisplayLink`, no timers |
| Reduce Motion (`UIAccessibility.isReduceMotionEnabled`) | No falling animation: render the 3 emoji in a single centered row "🏳️‍🌈 🏳️‍⚧️ 🇳🇴" that fades out over 1.5s (still fun, minus the vestibular assault) |

**State ownership (router, keeps the view dumb):**

```
// MastodonTabViewRouter
var isPrideRainActive = false
private(set) var prideRainTask: Task<Void, Never>?   // dismissal

func requestPrideRain() {
    guard !isPrideRainActive else { return }
    isPrideRainActive = true
    prideRainTask?.cancel()
    prideRainTask = Task { try? await Task.sleep(for: .seconds(4)); Self.isPrideRainActive = false }
}
```
(Tap-counter lives wherever the winning trigger surface lives: router for L1/L2, view-local for L3.)

**Tap counter (pure, unit-testable — extract to a small struct):**

```
struct MultiTapCounter {
    let requiredTaps = 5
    let window: TimeInterval = 2.0
    private(set) var tapTimes: [Date] = []
    mutating func registerTap(now: Date = .init()) -> Bool /* fires */ {
        tapTimes.append(now)
        tapTimes.removeAll { now.timeIntervalSince($0) > window }
        return tapTimes.count >= requiredTaps && (tapTimes.removeFirst() != nil)
    }
    mutating func reset() { tapTimes = [] }
}
```
Unit tests: 5-in-window fires once; spread-out taps never fire; counter self-prunes (no unbounded growth).

## 5. Files to touch (integration map)

| File | Change |
|---|---|
| `Mastodon/In Progress New Layout and Datamodel/MastodonMainTabView.swift` | Tap/long-press gesture at winning surface; `.overlay(alignment: .top)` PrideRainView; haptic call |
| `Mastodon/In Progress New Layout and Datamodel/MastodonTabViewRouter.swift` | `isPrideRainActive` + dismissal task (§4) |
| `Mastodon/In Progress New Layout and Datamodel/… /PrideRainView.swift` (NEW) | Overlay view + `MultiTapCounter` |
| `MastodonTests/` (NEW) | MultiTapCounter unit tests (target default-on — no pbxproj edit needed) |
| ⚠️ **pbxproj gotcha** | New file lives in "In Progress New Layout and Datamodel" = **opt-in membership** — MUST be added to the `membershipExceptions` of folder `FBBEA04F` (target Mastodon) **or it silently won't compile** (per notes, streaming phase 1 lesson) |

## 6. Implementation phases

1. **Phase 0 — Spike (30–45 min, MUST be first):** debug tap-counter on the `.localFeed` tab label + a long-press `simultaneousGesture` on the "oslo.town" segment. Log observed events from the booted sim via `simctl` console. Decide L1/L2/L3 and record the result in this file's *Phase-0 outcome* line.
2. **Phase 1 — Core:** `MultiTapCounter` + unit tests green → router state → `PrideRainView` with fixed 3 emoji → wire trigger at winning surface. Acceptance: triggering works on sim, rain looks like §4, app fully interactive during rain.
3. **Phase 2 — Polish:** haptic (light, 5th tap), cooldown, Reduce Motion fallback, `.allowsHitTesting(false)` verified by interacting with the tab bar during rain.
4. **Phase 3 — Guard:** UI smoke test (§8) + full TabBarSmokeTests suite green; pixel sanity via screenshot (emoji present in top band, gone after 5s); commit with message "Easter egg: make it rain pride/Norwegian flags from the Oslo logo".

## 7. Accessibility

- The overlay is `accessibilityHidden(true)` — emoji rain is decoration, screen readers must stay silent.
- VoiceOver users otherwise cannot multi-tap the tab item reliably, so attach a hidden custom action on the Oslo tab label: `.accessibilityAction(named: <label>) { trigger() }`. Label: localized — propose new key `Scene.A11y.PrideRain.action` = "Make it rain" (en) / nb "La det regne" (add to the nb backlog review list; pl/uk/ar to be machine-assisted per house flow). If the translation is unwanted, fall back to emoji-only label "🏳️‍🌈" and skip L10n entirely — decide in Phase 2.
- Reduce Motion path per §4.

## 8. Testing

- **Unit (MastodonTests):** `MultiTapCounter` — fire-once, window pruning, reset. Fast, no app launch.
- **UI smoke (TabBarSmokeTests):** depending on winning surface, L1: `app.tabBars.buttons["Oslo"]` `.tap()` ×5 in a tight loop → assert some element exists… the rain is hit-test-free and (optionally) a11y-hidden, so for testability give the *Reduce Motion* row meaning: launch the test with `-UIAccessibilityReducedMotion 1`? Simpler: assert via screenshot-diff (non-empty top band content change) OR expose a debug `.accessibilityIdentifier("pride-rain")` **only when `ProcessInfo` UI-test launch argument is set**. Prefer the latter: deterministic, no pixel analysis, zero a11y pollution in production runs. Accept when: identifier appears ≤2s after the 5th tap and disappears ≤6s later.
- Regression: everything else in TabBarSmokeTests stays green (rain never autos during other tests — trigger is the only path).

## 9. Risks & gotchas (pre-collected)

| Risk | Mitigation |
|---|---|
| Tab-label gestures broken/swallowed by TabView (iOS 26) | Phase 0 spike + Trigger Ladder L2/L3 — this is exactly why the spike is mandatory |
| New file in opt-in folder silently not compiled | Add to pbxproj `membershipExceptions` (FBBEA04F) — see §5 |
| Emoji rendering: 🇳🇦? | Use regional-indicator "🇳🇴" (letters N+O); verify on iOS 27.2 sim in Phase 1 (expected fine — iOS 14.2+ has both flags) |
| Glass capsule layering | Overlay on the TabView host — verify rain renders ABOVE the floating tab bar (z-order on iOS 26 floating glass) during Phase 1 |
| Perf on old devices | 60 fixed particles, single TimelineView, no images — cheap; still assert Debug memory via Instruments if concerned |
| Accidental discovery annoyance | Cooldown + short duration; if it ever feels noisy, drop trigger to 2 taps of any current tab of the day… (not specced, see backlog) |

## 10. Acceptance criteria (definition of done)

- [ ] Phase-0 outcome recorded here: ___ (L1 / L2 / L3, with one-line evidence)
- [ ] 5 taps (or 1.2s long-press at winning surface) → rainbow/trans/Norwegian emoji rain from top of screen on iOS 27.2 sim
- [ ] Rain non-interactive, auto-gone by 4s, doesn't retrigger for 15s
- [ ] Tab bar, scrolling, composing all work DURING the rain
- [ ] Reduce Motion → static row fallback; overlay hidden from VoiceOver; custom a11y action exists to trigger it (with localized-or-emoji label decision made)
- [ ] MultiTapCounter unit tests + new UI smoke green + TabBarSmokeTests suite green
- [ ] AGPL house rules respected (no bundled third-party art, any labels localized via house flow)

---

*Prepared for implementation in a future session. No code written under this spec yet.*
