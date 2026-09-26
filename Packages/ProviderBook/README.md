# ProviderBook

Defines the audiobook-library contracts and data layer. The package ships **two products**:

- `ProviderBook` — the protocol/DTO/error surface (`BookProviding`, `BookDatabaseProviding`, `BookDTO`, `BookPluginError`, `BookPluginInfo`, `BookEvent` notification names, `BookPlaybackStateDTO`).
- `ProviderBookData` — the concrete SwiftData model and repository layer (`BookModel`, `BookState`, `BookDB` actor, `BookRepo`, `BookCoverRepo`, `BookSettingRepo`, `BookPathContainment`, `BookConfig`, `BookPluginHost`).

## Functional Logic

- **Core responsibility**: abstract cross-plugin access to the audiobook library (read books, sync imported files, persist playback position, fetch covers) and house the SwiftData persistence layer.
- **Key protocols / types**:
  - `BookProviding` (`@MainActor`, `AnyObject`): `bookDisk: URL?`, `isAvailable: Bool`, `totalCount() async -> Int`, `addObserver(_:)` returning `BookProvidingObserverHandle`.
  - `BookDatabaseProviding: BookProviding`: adds `databaseRoot: URL`, `books(reason:) async -> [BookDTO]`, `syncImportedItems(_:)`, `coverData(for:) async -> Data?`, `playbackState(for:) async -> BookPlaybackStateDTO?`, `savePlaybackState(for:currentURL:time:)`, `currentBookURL()`, `currentBookTime()`, `storeCurrentBookURL(_:)`, `storeCurrentBookTime(_:)`.
  - Events (`BookProvidingEvent`): `.librarySyncing`, `.librarySynced`, `.libraryChanged(totalCount:)`, `.libraryDeleted(urls:)`, `.librarySorted`, `.playbackStateChanged(url:)`, `.storageLocationChanged`.
  - `BookDTO`: `Sendable`/`Equatable` value type (`url`, `bookTitle`, `childCount`, `isCollection`, `order`; equality by URL).
  - `BookModel` (`@Model`) / `BookState` (`@Model`): SwiftData records with parent/child relationships, cover data, and per-book playback position; several `FetchDescriptor` helpers.
  - `BookDB`: `ModelActor` serializing SwiftData reads/writes — full/incremental disk sync, deletes, next/previous navigation, playback-state persistence.
  - `BookRepo`: `@MainActor` repository that monitors the library directory (with debounce + initial-sync waiters), filters displayable items off the main actor, and exposes `getAll(reason:)`, `find(_:)`, `getCover(for:thumbnailSize:)`.
  - `BookCoverRepo`: recursive cover search with a lock-protected in-flight cache; prefers `cover/folder/front/poster/thumbnail` names and skips non-downloaded iCloud files.
  - `BookSettingRepo`: persists current book URL/time to both `UserDefaults` and `NSUbiquitousKeyValueStore`.
  - `BookPluginHost`: static bootstrap hooks (`configure(dbRoot:storageRoot:storageLocationDidChangeNotifications:)`) used by feature plugins to resolve the shared DB/storage root without importing the lifecycle target.
  - `BookEvent`: `Notification.Name` constants (`bookDBSyncing`, `bookDBSynced`, `bookDBUpdated`, `bookStateUpdated`, `bookDBDeleted`, `bookDBSorting`, `bookDBSortDone`) with main-thread post helpers.
  - `BookPluginError`: localized errors (`.configurationMissing`, `.NoNextAsset`, `.NoPrevAsset`, `.NoDisk`, `.DiskNotFound`, `.initialization(reason:)`).
- **Dependencies**: `MagicKit`, `CisumUIComponents` (localized strings, `SuperLog`, URL helpers).

## Testing Logic

- **Test files**:
  - `Tests/BookLibraryPolicyTests.swift` — `BookDB.downloadProgressPercentText` clamping; `BookLibraryItemSupport` distinguishing playable files vs. collections; symlink/alias dedup via `uniqueSupportedBookLibraryItems`; stable insertion sort and duplicate-order detection; path containment; `BookModel` metadata derivation; `BookCoverRepo.getCoverData`; `BookRepo.shutdown` releasing initial-sync waiters.
  - `Tests/BookModelTests.swift` — `BookState` defaults and `currentTitle`; in-memory SwiftData fetch descriptors; URL identity across symlinks; `BookDTO` equality/collection helpers; filesystem sibling/child resolution; `BookPluginInfo.dirName`/extensions; `BookPluginError` localized descriptions.
  - `Tests/BookCoverageTests.swift` — `BookEvent` notification posts (including `userInfo` payloads); `BookSettingRepo` URL/time parsing and UserDefaults/NSUbiquitousKeyValueStore round-trips (serialized suite); `BookPluginHost.configure`/`getDBRootDir`/`getBookDisk`.
  - `Tests/BookPathContainmentTests.swift` — containment for root/descendants vs. sibling prefixes; canonical identity for missing files and remote URLs; symlinked libraries resolving to the same book.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderBook
  swift test
  ```
- **Note**: unlike most Provider packages, this one ships real logic (SwiftData actor, file-system monitoring, cover cache, path normalization). Tests cover that logic directly, including temporary filesystem fixtures and in-memory `ModelContainer`s.
