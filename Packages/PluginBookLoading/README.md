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
    `iconName = "icloud.and.arrow.down"`, `policy = .alwaysOn`.
  - `BookLoadingPluginInfo` — title "Book Loading", description "Show iCloud
    loading progress and recovery for audiobooks", `order = 9`.
  - `BookLoadingPlaybackCapability` / `BookLoadingPlaybackCapabilityAdapter` —
    narrow view of `PlaybackProviding`: state, current URL, cancel, retry, and
    only `.stateChanged` / `.assetChanged` events.
  - `BookLoadingSceneCapability` / `BookLoadingSceneCapabilityAdapter` — narrow
    read-only view of `SceneProviding`.
  - `BookLoadingViewModel` — derives `BannerMode` (`.hidden`,
    `.downloading(progress:)`, `.failed(detail:)`) from scene + playback state.
    Progress clamps to `0...1`; zero renders an indeterminate bar rather than
    "0%". Only `.iCloudDownloadFailed` becomes `.failed`; other failures stay
    hidden. Leaving the audiobooks scene only hides the banner and never cancels
    the load.
  - `BookLoadingObserver` — syncs the initial snapshot, then forwards scene and
    playback events to the view model.
  - `BookLoadingBanner` — banner view. Accessibility identifiers:
    `cisum.player.loading` (container), `.title`, `.subject`, `.progress`,
    `.cancel`, `.error`, `.help`, `.retry`. The raw engine detail is exposed only
    through the accessibility hint/tooltip.
- **Plugin registration:** in `onReadyAsync` / `onEnable` it resolves
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
naming, cancel/retry forwarding, banner body construction, and plugin lifecycle
including slot activation and teardown. See `Tests/TestPlan.md`.
