# PluginBookControlButtons

Audiobook playback-control plugin for Cisum. It injects a book-specific button row
(previous chapter, play/pause, next chapter, play-mode toggle, and a "more" button)
into the player control area, but only while the app is in the audiobooks scene.

## Functional Logic

- **Core responsibility:** provides the on-screen playback controls for audiobooks.
  It resolves the kernel's `SceneProviding`, `PlaybackProviding`,
  `BookDatabaseProviding` and `ToastProviding` providers, narrows them behind a
  small capability protocol, and drives chapter navigation with generation and
  scene-activation guards.
- **Key types/protocols:**
  - `BookControlButtonsPlugin` — `AsyncSuperPlugin`, `SuperLog`; singleton
    `shared`, `id = "BookControlButtonsPlugin"`, `order = 8`,
    `iconName = "playpause"`, `policy = .alwaysOn`, `category = .feature`.
  - `BookControlButtonsView` — the five `AppCircularIconButton` row (ellipsis /
    previous / play-pause / next / play-mode); sizes itself to the available
    geometry.
  - `BookControlViewModel` — `ObservableObject`; `@Published` `isPlaying`,
    `playMode`; `shouldActivateControl`; `toggle()`, `previous()`, `next()`,
    `togglePlayMode()`; chapter navigation with `controlGeneration` invalidation;
    handles book-DB deletes, library refreshes and storage resets.
  - `BookControlPlaybackCapability` protocol + `BookControlPlaybackCapabilityAdapter`
    — minimal surface (`currentURL`, `isPlaying`, `playMode`, `toggle()`,
    `togglePlayMode()`, `play(_:reason:)`, `reset(reason:)`) wrapping
    `PlaybackProviding`.
  - `BookControlPlaybackObserver` / `BookControlSceneObserver` — forward
    playback `.stateChanged` / `.playModeChanged` / `.previousRequested` /
    `.nextRequested` and scene `.selectionChanged` events to the view model.
  - `BookControlChapterSupport` — pure helpers: `BookControlBookRootResolver`
    (finds the top-level book folder for a chapter), `BookControlPathContainment`,
    `BookControlFileLocationIdentity`, `BookControlPlaybackRequestPolicy`
    (generation / scene / same-file guards), `BookControlChapterLoader`
    (recursive playable-file scan + adjacent-asset selection), `BookControlChapterCache`.
- **Plugin registration:** registered as `BookControlButtonsPlugin`. In `onRegister`
  it adds About/Manual docs. In `onBootAsync` it calls
  `PluginContributionProviding.addControlButtonsView`; `addControlButtonsView()`
  returns `nil` unless `SceneProviding.currentScene == .audiobooks`. `onReadyAsync`
  / `onEnable` build the view model, observers and book-provider subscription;
  `onDisable` / `onShutdownAsync` tear them down and remove contributions.
- **Workflow/data flow:** a button tap → view model computes the enclosing book root
  → lazily scans/caches playable chapters → picks the adjacent chapter per the
  current `MagicPlayMode` (sequence / loop / repeatAll wrap-around / shuffle) →
  applies the result only if the request generation, scene and current asset still
  match → calls `playbackCapability.play`. Deletes of the current book reset
  playback and clear the chapter cache; storage-location changes reset playback in
  the active scene.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `ProviderBook`,
  `MagicPlayMan`, `CisumKernelSupport`, `ProviderDocsView`, `ProviderScene`,
  `ProviderPlayback`, `ProviderRootView`, `ProviderToast`.

## Testing Logic

- **Test files:**
  - `Tests/BookControlPluginTests.swift` — covers metadata, chapter loader,
    navigation policy, book-root resolver, and view-model integration with probes.
- **Key scenarios tested:**
  - Registration metadata: `iconName == "playpause"`, `order == 8`.
  - Chapter navigation: `repeatAll` wraps around both ends, `sequence` stops at
    boundaries, shuffle excludes the current chapter.
  - Symlink handling: navigation matches a symlinked current chapter, shuffle
    candidates collapse real/symlinked duplicates while keeping distinct dangling
    symlink books separate.
  - Request policies: stale navigation results (generation mismatch, scene
    deactivated, asset switched) are rejected; navigation is rejected for audio
    outside the configured book disk; deletion affects the current chapter only
    when it lies inside a deleted book (through symlinks too).
  - Chapter cache: reuse after load, invalidation on delete/refresh, cache-key
    matching across symlinked roots.
  - Book-root resolution: standalone file at disk root, nested chapter maps to its
    top-level folder, outside-disk fallback to parent, symlinked disk mapping.
  - Chapter loader order (relative paths, skips hidden/unsupported files).
  - ViewModel integration via `BookControlPlaybackProbe` / `BookToastProbe`:
    init reflects playback state, unavailable-capability toasts, storage reset
    applies only in the active scene, deletion of the current chapter resets
    playback, and scene changes invalidate pending resets.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBookControlButtons
  swift test
  ```
