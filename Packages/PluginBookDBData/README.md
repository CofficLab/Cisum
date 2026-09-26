# PluginBookDBData

The audiobook database data layer for Cisum. It is the single place that builds and
owns the SwiftData container, the cached `BookRepo`, and the book-disk lifecycle.
All book UI plugins read and write through the `BookDatabaseProviding` provider this
package registers in the kernel; this package intentionally contains no SwiftUI views
and no settings contributions.

## Functional Logic

- **Core responsibility:** assemble the book database service. On boot it resolves
  `StorageProviding`, lazily constructs the SwiftData `ModelContainer` via
  `BookConfig.getContainer`, wraps it in `BookDB`, and caches a `BookRepo`. It
  exposes reads/writes, cover data, per-book playback state, and current-book
  persistence to the rest of the app.
- **Key types/protocols:**
  - `BookDBDataPlugin` — `SuperPlugin` (synchronous lifecycle), singleton `shared`,
    `id = "BookDBDataPlugin"`, `order = 11`,
    `iconName = "externaldrive.badge.timemachine"`, `policy = .alwaysOn`,
    `category = .feature`, name "Audiobook Database Data".
  - `BookDatabaseProvider` — `BookDatabaseProviding`; lazily builds/caches
    `BookRepo`, computes `bookDisk` (`storageRoot/audios_book`), `isAvailable`,
    `databaseRoot`; forwards `totalCount()`, `books(reason:)`,
    `syncImportedItems(_:)`, `coverData(for:)`, `playbackState(for:)`,
    `savePlaybackState(for:currentURL:time:)`; persists current book URL/time via
    `BookSettingRepo`; maps `NotificationCenter` book notifications to
    `BookProvidingEvent`; invalidates the cached repository on storage changes.
  - `BookProvidingNotificationObserverHandle` — cancels both the notification-center
    tokens and the storage observer handle.
- **Plugin registration:** registered as `BookDBDataPlugin`. In `onBootAsync` /
  `onReadyAsync` / `onEnable` it calls `installProvider(kernel:)`, which resolves
  `StorageProviding` and `kernel.registerProvider(BookDatabaseProviding.self, provider)`.
  `onDisable` / `onShutdownAsync` call `removeProvider(from:)` which shuts down the
  provider and unregisters. If a provider already exists, registration throws and the
  freshly built provider is shut down so the existing one is never stolen.
- **Workflow/data flow:** storage location changes → provider invalidates the cached
  repo (shutting it down) → next read rebuilds the container against the new disk.
  Book notifications (`.bookDBSyncing`, `.bookDBSynced`, `.bookDBUpdated`,
  `.bookDBDeleted`, `.bookDBSortDone`, `.bookStateUpdated`) are translated into
  `.librarySyncing` / `.librarySynced` / `.libraryChanged` / `.libraryDeleted(urls:)`
  / `.librarySorted` / `.playbackStateChanged(url:)` observer callbacks; sync events
  also clear `BookCoverRepo`'s cover cache.
- **Dependencies:** `CisumKernelSupport`, `MagicKit`, `ProviderBook`
  (products `ProviderBook` and `ProviderBookData`), `ProviderStorage`.

## Testing Logic

- **Test files:**
  - `Tests/BookDatabaseProviderTests.swift` — a `@Suite(.serialized)` suite using a
    `BookTestStorageProvider` fake storage and an event recorder.
  - `Tests/BookDBDataPluginTests.swift` — lightweight metadata assertions.
- **Key scenarios tested:**
  - Unavailable storage: empty reads, `nil` cover/state, writes throw
    `BookPluginError`, and `shutdown()` removes the storage observer.
  - Happy path: initial sync, `syncImportedItems`, cover/state reads, saving and
    reading playback state, and a storage-root switch that invalidates the repo and
    serves the new disk's books.
  - Notification mapping: each `Notification.Name` is translated to the expected
    `BookProvidingEvent`, and observer cancellation stops further delivery.
  - Plugin lifecycle: no provider is registered until storage is available; when
    storage is available the provider is registered on boot, removed on disable,
    re-registered on enable, and removed on shutdown.
  - Failure isolation: a duplicate-registration failure leaves the pre-existing
    provider in place and does not leak observers.
  - Metadata: `order == 11`, `category == .feature`,
    `iconName == "externaldrive.badge.timemachine"`.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBookDBData
  swift test
  ```
