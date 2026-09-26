# PluginBookProgress

The audiobook playback-progress plugin for Cisum. It remembers where the user left
off in each book, restores that chapter and position when entering the audiobooks
scene, persists progress on pause/scene leave, downloads not-yet-downloaded chapters,
and clears saved state when a book is deleted.

## Functional Logic

- **Core responsibility:** save and restore per-book listening position. It does not
  draw a progress bar itself; it drives the playback engine to resume correctly and
  writes `BookState` records through the data layer.
- **Key types/protocols:**
  - `BookProgressPlugin` — `AsyncSuperPlugin`, `SuperLog`; singleton `shared`,
    `id = "BookProgressPlugin"`, `order = 5`, `iconName = "book.closed"`,
    `policy = .disabled`, `category = .feature`.
  - `BookProgressPluginInfo` — title "Book Progress", description "Save and restore
    book playback progress", `iconName = "book.closed"`, `order = 5`.
  - `BookProgressViewModel` — `ObservableObject`; `shouldActivateProgress`;
    `handleSceneChange`, `handleCurrentURLChanged(_:)`,
    `handlePlayManStateChanged(_:)`, `handleBookDBDeleted(deletedURLs:)`,
    `restoreBookProgress()`, `persistCurrentProgress(reason:)`. Uses
    `restoreGeneration` to cancel stale restores.
  - `BookProgressPlaybackCapability` protocol (`currentAsset`, `state`, `currentTime`,
    `play(_:autoPlay:startTime:reason:)`, `seek(to:)`) +
    `BookProgressPlaybackCapabilityAdapter`.
  - `BookProgressObserver` — forwards scene changes, playback `.stateChanged` /
    `.assetChanged`, and book-provider `.libraryDeleted` events.
  - Policy/lookup helpers (in `BookProgressRootView.swift`):
    `BookProgressPersistencePolicy`, `BookProgressFileLocationIdentity`,
    `BookProgressBookRootResolver`, `BookProgressBookLookup`,
    `BookProgressPathContainment`, `BookProgressStateSnapshot`,
    `BookProgressSaveTrigger`.
  - Closure types: `BookProgressURLProvider`, `BookProgressTimeProvider`,
    `BookProgressStoreCurrentURL`, `BookProgressStoreCurrentTime`,
    `BookProgressDiskProvider`, `BookProgressSaveBookState`.
  - `BookProgressRootView<Content>` / `BookProgressPluginRootView` — passthrough
    wrappers.
- **Plugin registration:** registered as `BookProgressPlugin`. In `onRegister` it adds
  About/Manual docs. `onReadyAsync` / `onEnable` build the view model (wiring
  current-book URL/time getters/setters, `bookDisk`, and `savePlaybackState` through
  `BookDatabaseProviding`) and the observer; `onDisable` / `onShutdownAsync` tear
  them down. `addRootView(content:)` wraps content.
- **Workflow/data flow:** enter `.audiobooks` → restore: if a saved current book URL
  is playable and not already loaded, `play(url, startTime: time)`; if the same file
  is already loaded, `seek(to: time)` instead; if the saved URL is stale, clear it.
  While playing, URL changes persist the current chapter (and trigger
  `url.download` for remote files); pausing or leaving the scene persists the
  current time. Book deletes that contain the stored chapter clear the saved state.
  All async continuations are guarded by generation and scene-activation checks.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `ProviderBook`, `MagicPlayMan`,
  `CisumKernelSupport`, `ProviderDocsView`, `ProviderScene`, `ProviderPlayback`.

## Testing Logic

- **Test files:**
  - `Tests/BookProgressPluginTests.swift` — extensive policy unit tests plus
    view-model integration with a playback probe.
  - `Tests/BookProgressStatePersistence.swift` — helper that upserts a `BookState`
    (current chapter + time) into an in-memory SwiftData container and posts
    `.bookStateUpdated`.
- **Key scenarios tested:**
  - Snapshot semantics: URL-only changes don't overwrite saved time; position changes
    normalize NaN/inf/-1 to 0; a different book URL resets global time; unchanged URL
    doesn't re-persist.
  - Symlink handling: symlinked real chapters are treated as the same file (no reset,
    no re-persist, seek-only restore), while distinct dangling symlink books are kept
    separate.
  - Delete cleanup: stored current chapter is cleared when its file/book (through
    symlinks) is deleted; a distinct dangling symlink book is untouched.
  - Disk boundary: progress is only persisted for URLs inside the configured book
    disk; symlink escapes outside the disk are rejected; outside-disk audio is
    ignored.
  - Restore guards: stale generations and scene deactivation discard results; an
    already-loaded chapter is seeked rather than replayed; nested chapters resolve to
    their top-level book folder; root-level files and root disk containment.
  - `BookState` persistence: upsert updates existing state in place and dedupes
    symlinked book records.
  - ViewModel integration: scene activation restores stored progress with the right
    start time, already-loaded assets only seek, paused playback persists time, and
    deletion of the current book clears stored URL/time.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBookProgress
  swift test
  ```
