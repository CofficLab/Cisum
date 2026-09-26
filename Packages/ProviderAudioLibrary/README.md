# ProviderAudioLibrary

Defines the audio-library capability contracts (`AudioLibraryProviding`, `AudioLibraryOrderingProviding`), plus shared metadata (`AudioPluginInfo`) and diagnostics (`AudioStorageDiagnostics`). SwiftData, filesystem scanning, repository and event bridging live in `PluginAudioDBData`; this package only declares the boundary.

## Functional Logic

- **Core responsibility**: abstract the audio database/library read/write/sort surface that the kernel and playback UI depend on, without coupling to any concrete audio plugin.
- **Key protocols / types**:
  - `AudioLibraryProviding` (`@MainActor`, `AnyObject`, `Sendable`):
    - Properties: `audioDisk: URL?`, `supportedExtensions: [String]`, `isAvailable: Bool`.
    - Methods: `totalCount()`, `allURLs(reason:)`, `urls(offset:limit:reason:)`, `contains(_:)`, `delete(urls:verbose:)`, `sync(urls:verbose:isFirst:)`, `sort(url:reason:)`, `sortRandom(url:reason:verbose:)`, `addObserver(_:)`.
  - `AudioLibraryOrderingProviding`: narrower sort-only surface (`sort`, `sortRandom`) used by play-mode plugins.
  - `AudioPluginInfo`: build-time constants (`dbDirName` = `audios`, `debugDBDirName` = `audios_debug`, `effectiveDBDirName` switches on `DEBUG`, `supportedExtensions`, `maxAudioCount`, `titleKey`, `descriptionKey`).
  - `AudioStorageDiagnostics`: `Sendable`/`Equatable` struct that captures each stage of repository-path resolution (raw `StorageLocation`, iCloud availability, container/docs URLs, storage root, audio disk) and derives a human-readable `failureReason` and multi-line `summary`.
- **Events** (`AudioLibraryProvidingEvent`): `.syncing`, `.synced(totalCount:)`, `.updated(totalCount:)`, `.deleted(urls:totalCount:)`, `.sorting`, `.sortCompleted`. `AudioLibraryProvidingError.unavailable` is the transport error.
- **Provider pattern**: an audio plugin registers an implementation at `onBoot`; consumers resolve it via the kernel. The default `addObserver` returns `NoopAudioLibraryProvidingObserverHandle`.
- **Dependencies**: none (Foundation only).

## Testing Logic

- **Test file**: `Tests/ProviderAudioLibraryTests.swift`.
- **Key scenarios tested**:
  - A stub conforms to `AudioLibraryProviding`; default `addObserver` returns the no-op handle and never fires callbacks.
  - `AudioLibraryProvidingError.unavailable` is pattern-matchable and `Sendable`.
  - `AudioPluginInfo.effectiveDBDirName` matches the correct debug/release directory and `supportedExtensions` is the expected nine-item list.
  - `AudioStorageDiagnostics.failureReason` covers five failure branches (location unset, iCloud unavailable, iCloud container unresolved, storage root unresolved, audio repo dir uncreatable) and returns `nil` when the repository is ready; `summary` embeds the resolved paths.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderAudioLibrary
  swift test
  ```
- **Note**: provider package; tests exercise the protocol conformance, constants, and the pure diagnostics logic rather than a live database.
