# PluginBook

The base audiobook plugin for Cisum. It bootstraps the audiobook feature inside the
kernel: resolves the storage and book-database providers, assembles the root
container state, and renders the top-level book view (loading / error / content).
Shared book models, database, repositories, and notifications are owned by
`ProviderBook`; the app and sibling `PluginBook*` packages depend on that
provider directly.

## Functional Logic

- **Core responsibility:** the entry/base plugin for the audiobook feature. It owns
  the root container lifecycle (install / teardown) and decides whether the book
  library is ready to show. The actual SwiftData container, `BookRepo`, `BookDB`,
  cover and settings repositories live in `ProviderBook`; this package wires them
  into the kernel and exposes them through `BookDatabaseProviding`.
- **Key types/protocols:**
  - `BookPlugin` — `AsyncSuperPlugin`, `SuperLog`; singleton `shared`,
    `id = "BookPlugin"`, `order = 1`, `policy = .disabled`, `category = .feature`.
  - `BookRootViewModel` — `ObservableObject`; `@Published` `error`, `isLoading`,
    `storageLocationDidChangeNotice`; `reloadContainer()`,
    `handleStorageLocationChanged()`. Uses a generation counter so stale async
    reloads cannot clobber newer state.
  - `BookStorageObserver` — subscribes `StorageProviding`
    (`.locationChanged`, `.storageAvailabilityChanged`) and drives the view model
    to reload; idempotent `cancel()`.
  - `BookRootView<Content>` — switches between error view, `ProgressView`, and the
    embedded content based on the view model; re-runs `reloadContainer()` on appear.
  - `BookPluginAboutView` / `BookPluginManualView` — docs landing and manual pages
    registered into `DocsViewProviding`.
- **Plugin registration:** registered with the kernel as `BookPlugin`. In
  `onRegister` it adds its About/Manual docs entries. In `onReadyAsync` /
  `onEnable` it resolves `StorageProviding` and `BookDatabaseProviding` and calls
  `installRootState(storage:bookProvider:)`. `onDisable` / `onShutdownAsync` call
  `teardownRootState()`. `addRootView(content:)` wraps content in `BookRootView`.
  Shared constants are declared by `ProviderBook` and imported directly by
  consumers that use them.
- **Workflow/data flow:** storage becomes available → `BookStorageObserver` fires
  → `BookRootViewModel.reloadContainer()` checks `bookProvider.isAvailable` →
  either reports a "Disk not found" error or clears loading and renders content.
  Storage-location changes bump `storageLocationDidChangeNotice` and reload the
  container again. All heavy database work is delegated to the data layer provider.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `ProviderBook`,
  `KernelCore (LumiKernel), ProviderPlugin, KitAppEvents`, `ProviderDocsView`, `ProviderStorage` (local SPM packages).

## Testing Logic

- **Test files:**
  - `Tests/BookPluginTests.swift` — the single, large test target.
- **Key scenarios tested:**
  - `BookPluginInfo` metadata exports: `dirName == "audios_book"`,
    `iconName == "book"`, `supportedExtensions` includes `m4b` and the full set of
    player-recognized audio extensions.
  - `BookDB.downloadProgressPercentText(forFraction:)` clamps NaN/negative/over-1 to
    `"0"`/`"100"`.
  - `BookDB` emits typed deletion events with the deleted URLs.
  - Library item support: symlinked book folders count as collections, folders with
    only images/notes are rejected, playable-child counting ignores non-audio files.
  - Symlink-aware dedup: `BookDB.uniqueSupportedBookLibraryItems` collapses
    real/symlinked duplicates by resolved identity while keeping distinct dangling
    symlink books separate.
  - `BookCoverRepo.coverCandidates` ordering (named covers first, direct files
    before nested folders, audio chapters ignored) and `BookCoverCache`
    concurrent-load dedup plus clear-invalidation behavior.
  - `BookSettingRepo` URL/time parsing: empty/legacy/whitespace inputs, local zero
    overriding stale cloud time, NaN/inf/-1 fallbacks, storage normalization.
  - `BookDB.contains` delete semantics (nested chapters, sibling books, symlinked
    roots, dangling symlinks, root disk), `BookRepo.isDisplayableLibraryItem`,
    stable path ordering on full/incremental sync, symlink matching, next-book
    traversal, batch deletion, order repair.
  - `BookRootViewModelTests` / `BookStorageObserverTests` use probe providers to
    verify loading completion, "disk not found" errors, storage-event reloads,
    stale-generation guarding, and observer cancellation.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBook
  swift test
  ```
