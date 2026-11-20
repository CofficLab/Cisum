# PluginBookLoading

The audiobook iCloud loading plugin for Cisum. It replaces the bare-percentage
loading state with a named, cancellable, retryable banner in the player control
area — only while the audiobooks scene is active.

## Functional Logic

- **Core responsibility:** show where the current audiobook stands in its iCloud
  load and offer the two actions the engine exposes: cancel the wait, or retry
  the last failed load. It never touches the playback engine directly.
- **Key types/protocols:**
  - `BookLoadingPlugin` — `AsyncSuperPlugin`, `SuperLog`; singleton `shared`,
    `id = "com.coffic.cisum.plugin.book-loading"`, `order = 9`,
    `iconName = "icloud.and.arrow.down"`, `policy = .enabledByDefault`.
  - `BookLoadingPluginInfo` — title "Book Loading", description "Show iCloud
    loading progress and recovery for audiobooks", `order = 9`.
  - `BookLoadingPlaybackCapability` / `BookLoadingPlaybackCapabilityAdapter` —
    narrow view of `PlaybackProviding`: state, current URL, cancel, retry, and
    only `.stateChanged` / `.assetChanged` events.
  - `BookLoadingSceneCapability` / `BookLoadingSceneCapabilityAdapter` — narrow
    read-only view of `SceneProviding`.
  - `BookLoadingLibraryCapability` / `BookLoadingLibraryCapabilityAdapter` —
    narrow view of `BookDatabaseProviding`: the book list, the library root, and
    the playable extensions. It is resolved lazily so plugin boot order does not
    matter.
  - `BookLoadingSubject` / `BookLoadingSubjectResolver` — maps the chapter URL to
    a book title and "chapter n of m". It mirrors playback ordering (recursive
    files, extension filter, relative-path `localizedStandardCompare`) and falls
    back to the file stem without guessing when the library has no record.
  - `BookLoadingViewModel` — derives `BannerMode` (`.hidden`,
    `.downloading(progress:)`, `.failed(detail:)`) from scene + playback state.
    Progress clamps to `0...1`; zero renders an indeterminate bar rather than
    "0%". Only `.iCloudDownloadFailed` becomes `.failed`; other failures stay
    hidden. Leaving the audiobooks scene only hides the banner and never cancels
    the load. Asset changes start a subject resolution with a generation guard,
    so a stale lookup can never overwrite the current chapter.
  - `BookLoadingObserver` — syncs the initial snapshot, then forwards scene,
    playback and library events to the view model.
  - `BookLoadingBanner` — mirrors `docs/ux/audiobook-download-states.html`:
    a glass card with an iCloud icon, loading title, bold percentage, a book line
    (`《title》  Chapter n of m`), a 4pt progress track, and a footer hint plus
    Cancel link. The failed card uses the error tint and a filled Retry button;
    the raw engine detail is exposed only through the accessibility hint/tooltip.
    Because the slot is height-neutral, compact heights drop the footer hint
    (below 78pt) and tighten padding/spacing while moving Cancel into the title
    row (below 70pt); the book line is always kept. Accessibility identifiers:
    `cisum.player.loading` (container), `.title`, `.subject`, `.progress`,
    `.cancel`, `.error`, `.help`, `.retry`.
- **Plugin registration:** in `onRegister` it publishes the About and Manual
  docs entries through `DocsViewProviding` when that provider exists. In
  `onReadyAsync` / `onEnable` it resolves
  `SceneProviding`, `PlaybackProviding`, and `ControlViewProviding`, installs a
  `ControlLoadingSlot` via `setLoadingSlot`, and mirrors
  `viewModel.$mode != .hidden` onto `slot.isActive`. `onDisable` /
  `onShutdownAsync` cancel both observers, deactivate the slot, and call
  `setLoadingSlot(nil)`.
- **Cooperating plugins:** `PluginPlaybackProgress` keeps the music-side progress
  UI; the hero cover no longer draws a download ring. `PluginBookControlButtons`
  disables the play button while the engine reports a loading state.

## Tests

Run:

```bash
cd Packages/PluginBookLoading
swift test
```

`Tests/BookLoadingTests.swift` covers mode derivation, scene gating, subject
naming and book/chapter resolution (library match, nested directories, parent
fallback, top-level single-file books), cancel/retry forwarding, banner body
construction, docs registration, and plugin lifecycle including slot activation
and teardown. See `Tests/TestPlan.md`.
