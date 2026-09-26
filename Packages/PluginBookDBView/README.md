# PluginBookDBView

The audiobook repository browser for Cisum. It renders the main book grid inside the
audiobooks scene, handles drag-and-drop / file-importer import of audiobook folders
and audio files, and contributes a settings pane that lists the library as both a
book list and a directory tree. It reads all data through `BookDatabaseProviding`
(the service owned by `PluginBookDBData`) and never constructs the SwiftData
container itself.

## Functional Logic

- **Core responsibility:** the UI for browsing and importing the local audiobook
  library, plus the settings-window inspection of the repository. It owns grid/list
  display, cover loading, tap-to-play with resume-position restore, and the
  copy-to-repository import pipeline.
- **Key types/protocols:**
  - `BookDBViewPlugin` — `AsyncSuperPlugin`, `SuperLog`; singleton `shared`,
    `id = "BookDBViewPlugin"`, `order = 12`, `iconName = "books.vertical"`,
    `policy = .alwaysOn`, `category = .feature`.
  - `BookDBViewPluginInfo` — `titleKey = "Audiobook Repository"`,
    `descriptionKey = "Audiobook database view"`, `iconName = "books.vertical"`.
  - `BookDBView` — public root view; hosts `BookGrid`/`BookList`, the `.fileImporter`
    and `.onDrop` import flows, and the static import helpers (`copy(_:)`,
    `copyImportedItems`, `importableSourceCandidates`, `uniqueImportSources`,
    `folderContainsPlayableFiles`, `isDestinationNestedInSource`,
    `droppedFileURL(from:)`).
  - `BookGridViewModel` — `ObservableObject`; `@Published` `books`, `bookURLIndex`,
    `isLoading`, `isSyncing`, `selectedBookURL`, `syncingTotal/Current`,
    `lastStateUpdatedURL`; debounced book loading; `handleBookTap` resumes saved
    playback state before playing.
  - `BookListViewModel` / `BookTreeViewModel` — independent settings-only loaders so
    the settings pane does not share state with the main window.
  - `BookGrid`, `BookList`, `BookTile` (cover + deterministic colored placeholder),
    `BookDBTips` (empty/loading states), `BookDBUnavailableView`, `BookDBSettingView`
    (List / Directory-tree segmented control + repository path + open-in-Finder),
    `BookTreeView`, `BtnChapters` (stub), `ChapterTile`.
  - `BookPlaybackOrdering` — recursive playable-file scan, relative-path ordering,
    same-file/containment checks.
  - `BookTreeNode` / `BookTreeBuilder` — outline-group-friendly directory tree.
  - `BookDBPlaybackCapability` protocol + `BookDBPlaybackCapabilityAdapter` —
    `play(_:startTime:)` wrapped around `PlaybackProviding`.
  - `DBObserver` / `PlaybackObserver` — forward book-provider and playback events to
    the grid view model.
  - Policy helpers: `BookGridUpdatePolicy`, `BookGridPlaybackRequestPolicy`,
    `BookGridSelectionPolicy`, `BookGridPlayableChildrenLoader` (cached scan),
    `BookTileColorPolicy`, `BookTileStateRefreshPolicy`, `BookTileLoadIdentity`.
  - Dependency containers: `BookDBViewDependencies` (main content) and
    `BookDBDependencies` (settings).
- **Plugin registration:** registered as `BookDBViewPlugin`. In `onRegister` it adds
  About/Manual docs. In `onBootAsync` it registers a tab view contributor and a
  settings navigation item (`id = "bookdb"`). `addTabView(reason:demoMode:)` returns
  `nil` unless the scene is `.audiobooks`; if the book provider is missing it shows
  `BookDBUnavailableView`, otherwise it builds `BookDBView`. `onReadyAsync` /
  `onEnable` build the grid view model plus `DBObserver` and `PlaybackObserver`;
  `onDisable` / `onShutdownAsync` tear them down and remove contributions.
- **Workflow/data flow:** appear → debounced `bookProvider.books(reason:)` → grid of
  `BookTile`s (each loads cover data + playback state independently). Tap a tile →
  look up saved playback state (per-book, then global current book) → play the saved
  chapter at saved time, else the first playable child, else the file itself.
  Import: dropped/selected URLs are filtered to supported extensions and folders,
  deduped by resolved identity, nested duplicates pruned, copied into the book disk
  with security-scoped access and unique destination names, then
  `syncImportedItems` refreshes the library.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`,
  `ProviderDocsView`, `ProviderBook`, `ProviderPlayback`, `ProviderScene`.

## Testing Logic

- **Test files:**
  - `Tests/BookDBViewPluginTests.swift` — metadata, import pipeline, drop handling,
    ordering, tile policies, tree builder, settings item.
  - `Tests/BookDBViewCoverageTests.swift` — probe-based adapter/observer/view-model
    and policy unit tests.
  - `Tests/BookDBViewBookStateLookup.swift` — helper that fetches a `BookState` by
    book URL (including symlink fallback) from a `ModelContext`.
- **Key scenarios tested:**
  - Import filtering: unsupported top-level files skipped, folders require playable
    files, skipped-source warnings, nested-in-selected-folder pruning, symlinked
    folders/files copied as real files, symlinked source dedup, dangling-symlink
    destination name collision handling, batch-failure cleanup, and rejection of
    destinations nested inside the source (including symlinked destinations).
  - Drop handling: `NSItemProvider` fileURL-data decoding with fallback to URL
    objects, error/partial-failure reporting, and no-op when no URLs load.
  - `BookPlaybackOrdering`: relative-path ordering across discs, sibling-prefix
    rejection, playable-child containment without scanning, symlinked children
    matching, and distinct dangling symlinks kept separate.
  - `BookTreeBuilder`: nested directory structure, hidden/unsupported file skipping,
    missing-root empty result.
  - Grid view model (via `PlaybackProbe`/`BookProbe`/`CapabilityProbe`): books load
    on appear, asset changes select/clear the matching book, taps play with and
    without saved resume state, sync flags toggle, disappear invalidates pending
    updates, and generation/selection guards block stale playback results.
  - Policies and tile color/reload identity determinism; settings navigation item
    metadata (`id == "bookdb"`).
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBookDBView
  swift test
  ```
