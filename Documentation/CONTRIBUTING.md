# Contributing

First, please read the Mastodon project [Contributing guide](https://github.com/mastodon/.github/blob/main/CONTRIBUTING.md).

In addition, note that user interface changes for our official apps are carried out through a design process that involves core team review - most changes of this kind will not be accepted as community contributions; if they are accepted, they will take time to go through this review.

## General Information

- File an issue to report a bug or feature request
- Translate the project in our [Crowdin](https://crowdin.com/project/mastodon-for-ios) project
- Make a Pull Request to contribute

## Bug Report

File an issue about the bug or feature request. Make sure you are installing the latest version of the app from TestFlight or App Store.

## Translation

This fork ships an allowlist of languages: **English (`en`/`en-US`), Norwegian Bokmål (`nb`), Polish (`pl`), Ukrainian (`uk`), and Arabic (`ar`)**. All other upstream locales have been pruned from the string catalogs and bundled resources. Norwegian Nynorsk is deferred.

Notes that carry over from upstream: the localizations use `.xcstrings` catalogs with a manually-maintained `L10nLookup` struct for typed accessors. The typed accessors in the generated `L10n` struct are still in use in the app but the file is no longer automatically updated; new accessors belong in `L10nLookup`.

### To add new localized strings:

- Edit the appropriate `.xcstrings` catalog under `MastodonSDK/Sources/MastodonLocalization/Resources/` to add the new string (keys follow the hierarchical naming conventions; the key should not be the English string itself).
- Provide the English value; for plural variation use the "Vary by Plural" context-menu option (Norwegian/Polish/Ukrainian use `one`/`other`; a few languages also use other categories).
- Translate the new key **only into the allowlist languages** (`nb`, `pl`, `uk`, `ar`). All other locales no longer exist in this fork; they are not re-added.
- Add a typed accessor in the `L10nLookup` struct matching the key hierarchy; argument names must match. Static strings can be `let`s; strings with substitutions must be functions.

### The catalog tooling

Both tools refuse to touch a catalog unless their serializer reproduces the file's exact hand-maintained formatting (byte-identical round-trip guard), so diffs stay surgical:

- `scripts/prune_localizations.py` — removes any non-allowlist locale that upstream merges may have reintroduced (catalogs, `.lproj` folders, pbxproj `knownRegions`/file references). **Re-run after every upstream merge**, then clean-build the products (incremental builds leave stale `.lproj` folders in build output).
- `scripts/add_nb.py scripts/nb_translations/<batch>.json` — applies Norwegian Bokmål translation batches (plain values or `{"plural": {"one": ..., "other": ...}}`), reporting coverage per catalog. Keys are added under the `nb` locale with `state: translated`.

### To modify translations:

- Any allowlist-language translation can be edited directly in the catalogs (locally via the Xcode string-catalog editor or the scripts above). There is no Crowdin integration in this fork; changes to other languages would be overwritten the next time upstream merges are pruned, so they should not be made.
- Norwegian Bokmål is being translated in reviewed batches: `scripts/nb_translations/`.

### To add a new language:

- Add the locale's translations to the catalogs, add the language code to `ALLOWLIST` in `scripts/prune_localizations.py`, and ensure it appears in the pbxproj `knownRegions` list (editing `Mastodon/Resources/Localizable.xcstrings` in the Xcode string-catalog editor updates `knownRegions`; manual JSON edits do not).

## Pull Request

You can create a pull request directly with small block code changes for bugfix or feature implementations. Before making a pull request with hundred lines of changes to this repository, please first discuss the change you wish to make via an issue.

Also, there are lots of existing feature request issues that could be a good-first-issue discussing place.

Follow the git-flow pattern to make your pull request.

1. Ensure you have started a new branch based on the `develop` branch.
2. Write your changes and test them on **iPad and iPhone**.
3. Merge the `develop` branch into your branch then make a Pull Request. Please merge the branch and resolve any conflicts if `develop` updates. **Do not force push your commits.**
4. Make sure the permission for your fork is open to the reviewer. Code style fix, conflict resolution, and other changes may be committed by the reviewer directly.
5. Request a code review and wait for approval. The PR will be merged when it is approved.

## Documentation

The documentation for this app is listed under the [Documentation](../Documentation/) folder. We welcome contributions for documentation.
