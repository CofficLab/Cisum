# PluginAudio

Root audio UI plugin for Cisum. It owns the audio root view shell and the storage-availability gate; the actual audio catalog implementation lives in `PluginAudioDBData`, while this package just composes the root view and waits until storage is ready.

## Functional Logic

- **Core responsibility**: Provide the top-level audio root view and gate the whole audio feature behind a usable storage location. Until `StorageProviding` reports a usable storage location, the root view shows a setup/error screen instead of the catalog. It also exposes the shared audio constraints (`maxAudioCount`, `supportedExtensions`, `dbDirName`) forwarded from `AudioPluginInfo`.
- **Key types / protocols**:
  - `AudioPlugin` — the plugin entry (`AsyncSuperPlugin`, `SuperLog`), `id = "AudioPlugin"`, `order = 1`, `policy = .disabled`.
  - `AudioRootView` — the SwiftUI root shell that wraps the child `content` and renders storage/error state.
  - `AudioRootViewModel` — holds `isInitializing`, `error`, and `storageLocationDidChangeNotice`; drives reload on storage changes.
  - `AudioStorageObserver` — subscribes to `StorageProviding` events and forwards reload/change callbacks to the view model.
  - `AudioRootError` / `AudioRootErrorPresentation` — error enum (`storageMissing`, `initialization`) plus presentation mapping to localized title/message/detail.
  - `AudioPluginAboutView` / `AudioPluginManualView` — docs entries registered with `ProviderDocsView`.
- **Plugin registration**: Registers with ID `AudioPlugin`. In `onRegister` it adds About/Manual docs entries. It does not register any Provider; instead it resolves `StorageProviding` and `AudioLibraryProviding` from the kernel. `addRootView(content:)` contributes the root view contribution to the shell.
- **Workflow / data flow**:
  1. `onReadyAsync` / `onEnable` resolve `StorageProviding`; if present, `installRootState` builds a long-lived `AudioRootViewModel` (with a `hasStorageLocation` closure bound to the kernel) and an `AudioStorageObserver`.
  2. `addRootView` always returns a stable `AudioRootView` backed by the long-lived view model (creating a temporary one on demand so the contribution is safe before `onReady`).
  3. The observer watches storage events; storage-location changes bump `storageLocationDidChangeNotice` and trigger `reloadContainer`. Errors are mapped by `AudioRootErrorPresentation` into user-facing guidance.
  4. `onDisable` / `onShutdownAsync` cancel the observer and release the view model.
- **Dependencies** (from `Package.swift`): `ProviderAudioLibrary`, `ProviderAudioLike`, `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `ProviderDocsView`, `ProviderStorage`. Resources: `Localizable.xcstrings`.

## Testing Logic

- **Test files**: `Tests/AudioRootViewTests.swift`.
- **Key scenarios tested**:
  - `AudioRootErrorPresentation` mapping: `.storageMissing` yields the storage-setup guidance (no detail); `.initialization("database is locked")` surfaces the underlying detail.
  - `AudioRootViewModel`: `reloadContainer` finishes initialization when storage exists and reports `.storageMissing` when it does not; repeated storage-location changes produce a fresh notice each time.
  - `AudioStorageObserver`: drives a reload on storage events (initial load, then missing-storage error + notice) and supports idempotent cancellation. A `StorageProviderProbe` stub stands in for `StorageProviding`.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudio
  swift test
  ```
