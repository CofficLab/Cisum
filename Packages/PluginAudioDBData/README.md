# PluginAudioDBData

The audio database data layer plugin. It is the single assembly and registration point for `AudioLibraryProviding` and `AudioTrackNavigationProviding`, owning the SwiftData model, the database container, the repository, filesystem synchronization, and event bridging. UI plugins consume it only through kernel-resolved provider protocols and never construct `AudioRepo` directly.

## Functional Logic

- **Core responsibility**: Own the audio catalog's consistency lifecycle. It assembles the SwiftData container and repository, scans the audio directory, keeps the in-memory database in sync with the filesystem (new / changed / deleted files), and rebuilds everything when the storage location changes. Filesystem synchronization is driven here rather than by a separate job plugin.
- **Key types / protocols**:
  - `AudioDBDataPlugin` — plugin entry (`AsyncSuperPlugin`, `SuperLog`), `id = "AudioDBDataPlugin"`, `order = 1`, `iconName = "externaldrive.badge.timemachine"`, `emoji = "💾"`, `policy = .alwaysOn`.
  - `AudioLibraryProvider` — concrete implementation of `AudioLibraryProviding` (queries, navigation, sort/random sort, delete, sync) backed by `AudioRepo`.
  - `AudioTrackNavigationProvider` — concrete implementation of `AudioTrackNavigationProviding` (next/previous/first/last URL) built on closures over the library provider.
  - `AudioModel` — the SwiftData audio record (title, path, order, folder flag, etc.).
  - `AudioDB` — the SwiftData container; `AudioRepo` — the repository over the database + filesystem; `AudioConfigRepo` — config persistence.
  - `AudioFileSystemMonitor` — observes the audio directory and reconciles filesystem changes with the data layer.
  - `AudioStorageObserver` — watches `StorageProviding` and triggers a monitor rebuild on location changes.
  - Errors split by topic: `AudioPluginError` (config/host), `AudioRecordDBError` (record read/write), `AudioModelError` (validation/file state), `AudioRepoError` (filesystem/sync), plus `AudioErrorLocalization`.
  - `URL+Directory` extension and `AudioEvent` typed events.
- **Plugin registration**: Registers with ID `AudioDBDataPlugin`. On boot/ready/enable it registers `AudioLibraryProviding` and `AudioTrackNavigationProviding` with the kernel, starts `AudioStorageObserver`, and launches `AudioFileSystemMonitor`. On disable/shutdown it tears down synchronization and unregisters the providers.
- **Workflow / data flow**:
  1. `onBootAsync` installs the providers; `onReadyAsync` additionally sets up the storage observer and starts the filesystem monitor.
  2. The monitor performs a first full scan, then reconciles incremental changes. Empty full syncs are only allowed for a readable, empty directory; otherwise an empty result set is ignored so a transient scan error cannot wipe the library.
  3. When the storage location changes, the storage observer cancels the old monitor and restarts a fresh one against the new repository.
  4. Navigation, sort, random sort, and delete operations go through `AudioRepo`; symlinked duplicates are resolved/deduplicated, and files outside the library root are rejected for deletion.
- **Dependencies** (from `Package.swift`): `CisumKernelSupport`, `MagicKit`, `CisumUIComponents`, `ProviderAudioLibrary`, `ProviderAudioNavigation`, `ProviderStorage`.

## Testing Logic

- **Test files**:
  - `Tests/AudioDBPluginTests.swift` — repository/database behavior.
  - `Tests/AudioFileSystemMonitorTests.swift` — synchronization lifecycle.
  - `Tests/AudioLibraryProviderTests.swift` — provider contract and lifecycle.
  - `Tests/AudioModelBehaviorTests.swift` — model derivation.
  - `Tests/AudioPluginErrorTests.swift` — user-facing error descriptions.
  - `Tests/AudioTrackNavigationProviderTests.swift` — navigation provider forwarding.
- **Key scenarios tested**:
  - Repository/DB: supported player extensions; dangling symlink replacement on disk creation; DB-update notification on the main thread; unique file dedup by resolved identity (keeping distinct dangling symlinks); next/previous ordered navigation with wrap-around at boundaries; skipping symlinked duplicate tracks; delete-by-URL removing files/models and rejecting out-of-library paths, the library root, and mixed batches; stable path-ordered sync; ignoring folders/unsupported files; clamping pagination bounds and random counts; batch download plan stopping at queue end.
  - Filesystem monitor: plugin is always-on; local file changes trigger a full sync; empty full-sync rules; stale monitor runs/events stop after restart; scan errors do not sync empty results; cancellation of a stale run does not stop the replacement.
  - Library provider: unavailable storage returns empty results and rejects required operations; synced library supports queries/navigation/sorting/deletion; storage-availability changes invalidate the repository; plugin lifecycle indexes existing audio; navigation provider reports unavailable when storage was not injected.
  - Model: uses provided metadata and folder flag; derives title/size from file when metadata is missing; falls back to filename for blank titles; fetch descriptors preserve ordering and folder filters.
  - Errors: each error type surfaces user-facing recovery details.
  - Navigation provider: forwards arguments and returns resolved URLs, propagating resolver errors unchanged.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioDBData
  swift test
  ```
