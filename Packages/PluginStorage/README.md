# PluginStorage

The storage provider and storage-settings plugin. It registers the kernel's `StorageProviding` service (data-root layout, per-plugin data directories, database file URLs), contributes a "Storage" settings page to choose between iCloud and local media storage, and implements a file browser plus a safe migration flow between storage locations.

## Functional Logic

- **Core responsibility:** Own the on-disk data layout and the media-storage location choice, migrate media files between iCloud and local storage with progress, and provide file-browsing views for the current repository.
- **Key types:**
  - `StoragePlugin` — `@MainActor final class` conforming to `AsyncSuperPlugin, SuperLog`. `id = "StoragePlugin"`, `order = 10`, icon `"internaldrive"`, category `.feature`, policy `.alwaysOn`.
  - `StorageProvider` — `@MainActor final class` conforming to `ObservableObject, StorageProviding`. Builds the data root at `~/Library/Application Support/<bundleID>/db_<debug|production>_v<majorVersion>/`, provides `databaseRoot`, `databaseFile(name:)`, `pluginDataDirectory(for:)`, resolves iCloud/local/custom roots, persists the selected location in `UserDefaults` key `"StorageLocation"`, and broadcasts `.cisumStorageLocationDidChange` / `.cisumStorageLocationDidReset`. Exposes a static `current` bridge and `makePluginDependencies()` for legacy views.
  - `StoragePluginLocation` — public enum `icloud`/`local`/`custom` with emoji/titles/descriptions; bidirectional conversion to/from `ProviderStorage.StorageLocation`.
  - `StorageDependencies` — legacy closure-based dependency struct (location getter/setter, root resolver, isDesktop) with a `preview` instance.
  - `StorageSettingsCapability` — internal protocol narrowing storage to current location, root, availability, root-for-location, and set-location; `StorageSettingsCapabilityAdapter` adapts the provider.
  - `StorageProvidingObserver` — forwards provider changes to the settings view model (initial sync then observe).
  - `StorageSettingsViewModel` — `ObservableObject` publishing `location`, `isICloudAvailable`, `isLocalStorageAvailable`, and `storageRoot`/`storageRoot(for:)`.
  - `StorageSettingView` — settings UI listing iCloud/Local rows (with availability states), an "Open Current Repository" action, and a migration progress sheet.
  - **FileInfo/** — file-browsing components: `FileItem` (identifiable, expandable directory node), `FileListView` (generational visible-items list with expansion), `FileInfoView`, `FileIconView`, `FileTitleView`, `FileExpandButton`, `FileSizeView` (streams directory sizes), `FileStatus`/`FileStatusColumnView` (idle/processing/completed/failed and download progress states).
  - **Migrate/** — `MigrationManager` (copies files between roots, cancels safely, avoids nested target dirs, handles symlinks), `MigrationProgressView` (generational progress UI, alerts, completion), `MigrationError`, `RepositoryInfoView`.
  - Views: `StoragePluginAboutView`, `StoragePluginManualView`.
- **Plugin registration:** Registers as `StoragePlugin`. `onBootAsync` creates `StorageProvider`, sets `StorageProvider.current`, registers it as `StorageProviding`, contributes the "storage" settings navigation item, and installs the settings state. `onShutdownAsync` clears the static reference and tears down observers.
- **Workflow/data flow:**
  1. The provider computes the data root and resolves the selected media root (iCloud or local).
  2. The settings page shows availability per location; choosing a different location opens `MigrationProgressView`, which uses `MigrationManager` to copy files and update the persisted location on success.
  3. File-browsing views (`FileListView`, etc.) render the current repository with sizes and download status.
- **Dependencies:** `CisumUIComponents`, `CisumKernelSupport`, `ProviderDocsView`, `MagicKit`, `ProviderStorage`. Platforms: macOS 14+, iOS 17+. Resources: `Resources/Localizable.xcstrings`.

## Testing Logic

- **Test files:**
  - `Tests/StoragePluginTests.swift` — a large suite (~30 tests) covering storage info, file listing, file size/status, migration, and settings behavior.
- **Key scenarios tested:**
  - Plugin info metadata; `FileItem` directory-read failures.
  - File list generation only applies the latest visible-items update (generation guard), refreshes the cache on re-expansion, and tracks repository URL changes.
  - Expand-button accessibility label; file-info cells only apply results for the current file (including symlinked files, and correctly rejecting results across distinct dangling symlinks).
  - File-size policy reads Foundation number attributes, clamps negatives, streams directory sizes, and reads single-file sizes.
  - File status reports missing local files, clamps download percent text, and ignores local directories/hidden files during scans.
  - Repository info only opens existing local paths; storage settings clear the displayed selection after reset and sync the target after external location changes.
  - Migration progress only applies the current generation, normalizes invalid values, preserves download state on failure, completes only after source files leave, ignores unknown files, and disables interactive dismissal only while running.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginStorage
  swift test
  ```
- Tests are extensive and focus on the pure, deterministic policies (generation guards, size parsing, symlink handling, migration messaging) rather than on actually copying files.
