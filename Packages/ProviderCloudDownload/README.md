# ProviderCloudDownload

Defines the `CloudDownloadProviding` protocol: iCloud file download progress, broadcast to every consumer as it changes.

## Functional Logic

- **Core responsibility**: expose per-file iCloud download progress (`0...1`) to the app, so views can render progress rings without knowing how iCloud works.
- **Key protocol**: `CloudDownloadProviding` (`@MainActor`, `AnyObject`, `Sendable`):
  - Observation: `addObserver(_:)` returns `CloudDownloadProvidingObserverHandle`.
  - Snapshot: `progress(for:) -> Double`.
- **Events** (`CloudDownloadEvent`): `.progressChanged(url: URL, progress: Double)`.
- **Broadcast model**: the provider broadcasts progress for **all** downloading files and accepts **no** URL subscription registration. Callers never declare an interest set, so paging, scrolling, and deletion need no bookkeeping. This is viable because the underlying query predicate is `IsDownloadingKey == YES` — the result set is inherently tiny.
- **Implementation** (`CloudDownloadService`): owns one `NSMetadataQuery` and forwards system percentages as domain events. Completion is detected from the `removed` diff (a finished file leaves the result set).
- **Provider pattern**: consumers resolve via `kernel.resolveProvider((any CloudDownloadProviding).self)`. The default `addObserver` returns `NoopCloudDownloadProvidingObserverHandle`; `cancel()` is idempotent.
- **Dependencies**: `KitEventObservation` + Foundation only. No MagicKit, no SwiftUI, no ObservableObject.

## Design notes

- **Events are the source of truth, snapshots only initialize.** For dataless
  placeholder files the resource-key snapshot reads `0` in production; only
  `NSMetadataQuery` pushes reflect real progress. `progress(for:)` seeds a
  consumer's state before subscription and returns `1` for files that are
  downloaded or not iCloud-backed.
- **Progress is monotonic.** Progress and snapshots can both read `0`, so a late
  `0` must never overwrite a published value — otherwise a ring jumps from 50% back
  to 0%. `CloudDownloadProgressPolicy.merged` takes the max.
- **Matching is by full path, not filename.** `NSMetadataItem` carries
  `NSMetadataItemPathKey`, so identity uses `standardizedFileURL.path`. Matching on
  `lastPathComponent` would cross-feed progress between same-named files in
  different directories. When the path key is unavailable the item is **skipped**
  rather than guessed — a missing event is better than a wrong one.
- **Why not reuse MagicKit.** `MagicKit.GlobalDownloadMonitor` is package-internal
  (not visible cross-package) and matches subscribers by filename. It also remains
  in use by `MagicPlayMan`, so it is deliberately left untouched.

## Testing Logic

- **Test file**: `Tests/CloudDownloadProvidingTests.swift`.
- **Key scenarios tested**:
  - Identity keys use standardized absolute paths and distinguish same-named files
    in different directories.
  - Progress normalization clamps out-of-range and non-finite values.
  - Monotonic merge never regresses, including when one side is `NaN`.
  - Default `addObserver` returns a `NoopCloudDownloadProvidingObserverHandle`
    without invoking callbacks; repeated `cancel()` is safe.
  - The production service delivers no events after `cancel()`, and reports a
    plain local file as complete (`progress == 1`).
- **Running tests**:
  ```bash
  cd Packages/ProviderCloudDownload
  swift test
  ```
- **Note**: provider package; tests cover policy and identity logic plus the
  observer contract. Real iCloud download progress requires a signed-in device
  with a dataless file, which CI cannot produce.