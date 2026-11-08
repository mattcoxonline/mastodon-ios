# oslo.town for iOS

The iOS client for **[oslo.town](https://oslo.town)** — a single-server Mastodon community app,
built as a fork of [Mastodon for iOS](https://github.com/mastodon/mastodon-ios).

## About this app

This fork is tailored to one instance and one community. Unlike the official
multi-server Mastodon client, everything here assumes oslo.town:

- **Single-instance onboarding** — sign-in and registration go straight to
  oslo.town; there is no server picker or instance browser.
- **Live timelines via streaming** — the home, Oslo, Everything, hashtag, and
  list feeds maintain a Mastodon streaming (WebSocket) connection while you
  read, so new posts arrive without re-fetching.
- **Oslo tab** — the local community timeline is a first-class, brand-marked tab.
- **Mentions-first conversations** — the notifications tab opens on the
  mentions scope, prioritising conversations over likes and boosts.
- **Trend Board** — the Explore › Hashtags page is a ranked board with daily
  movement, sparklines, and a Today / This Week toggle, computed on-device
  from the trends API.
- **Curated Directory** — Explore › Directory shows community collections.
- **Devices & languages** — iOS 26 design system throughout (SF Symbols,
  Liquid Glass toolbars, the compose bar), localization pruned to
  `en · nb · pl · uk · ar`, with an ongoing Norwegian Bokmål translation
  (see `scripts/nb_translations/`).

## Building

Requirements:

- Xcode 27.2 or newer
- iOS 18.6+ deployment target (iOS 26 APIs are gated with `#available`)

Open `Mastodon.xcodeproj`, pick the **Mastodon** scheme and an iOS simulator,
and build. After signing in to an oslo.town account, the app is fully
functional on the simulator; see [Documentation/Setup.md](./Documentation/Setup.md)
for details.

Two build notes that may bite:

- SwiftGen runs as a build phase with user-script sandboxing **disabled**
  (`ENABLE_USER_SCRIPT_SANDBOXING = NO`) — if Xcode offers to "apply
  recommended settings", decline it.
- After adding files to the SDK (new Swift files, asset catalogs), a stale
  incremental build can produce false "no member" errors or missing assets;
  building the **MastodonSDK** scheme first (or a clean) resolves it.

## Original project

This app is a fork of the official Mastodon iOS client by the Mastodon team:
[github.com/mastodon/mastodon-ios](https://github.com/mastodon/mastodon-ios).
The upstream project is where the vast majority of this codebase comes from,
and where most general fixes and features continue to land; this fork
periodically merges from upstream.

Original app blog post: [Developing an official iOS app for Mastodon](https://blog.joinmastodon.org/2021/02/developing-an-official-ios-app-for-mastodon/).

## Acknowledgments

Thanks to [these open-source projects](./Documentation/Acknowledgments.md).

## License

This project is released under the [GPL-3 License](./LICENSE), inherited from
the original Mastodon for iOS project. The Mastodon name and logo are
trademarks of the Mastodon non-profit organisation; this app uses the
oslo.town name and branding and is not affiliated with or endorsed by the
Mastodon organisation.
