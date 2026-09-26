# ProviderStorage

Defines `StorageProviding` (the persistent-storage location contract) and the `StorageLocation` enum. The kernel only depends on this protocol; concrete iCloud/local resolution lives in the storage plugin.

## Functional Logic

- **Core responsibility**: unify where app data lives (iCloud container, local Documents, or a future custom location), resolve database and per-plugin directories under it, and broadcast location changes.
- **Key types**:
  - `StorageLocation`: `String`-backed enum (`icloud`, `local`, `custom`) — `Sendable, Codable, CaseIterable`. Exposes `emojiTitle`, `emoji`, `title`, and a human-readable `description`. Raw values are kept stable for backward compatibility with the legacy `UserDefaults` key `"StorageLocation"`.
  - `StorageProviding` (`@MainActor`, `AnyObject`, `ObservableObject`):
    - Read: `currentStorageLocation: StorageLocation?`, `storageRoot: URL?`, `hasUsableStorageLocation: Bool`, `isICloudStorageAvailable: Bool`, `databaseRoot: URL`.
    - Resolution: `storageRoot(for:) -> URL?`, `databaseFile(name:) throws -> URL` (builds `<name>/<name>.db`), `pluginDataDirectory(for pluginID:) -> URL` (`<databaseRoot>/<pluginID>/`).
    - Mutations: `setStorageLocation(_:)` (persists + broadcasts), `resetStorageLocation()`.
    - Observation: `addObserver(_:)` returns `StorageProvidingObserverHandle`.
- **Events** (`StorageProvidingEvent`): `.locationChanged(StorageLocation?)`, `.storageAvailabilityChanged`.
- **Provider pattern**: consumers resolve via `kernel.resolveProvider((any StorageProviding).self)`. Default `addObserver` returns `NoopStorageProvidingObserverHandle`.
- **Dependencies**: none (Foundation only).

## Testing Logic

- **Test file**: `Tests/StorageLocationTests.swift`.
- **Key scenarios tested**:
  - For each `StorageLocation` case, raw value, emoji title, emoji, plain title, and description are pinned; encoding/decoding round-trips.
  - Legacy raw strings (`"icloud"`, `"local"`, `"custom"`) decode back to the corresponding cases.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderStorage
  swift test
  ```
- **Note**: provider package; tests pin the persisted enum values and presentation strings. Real path resolution is exercised by the storage plugin.
