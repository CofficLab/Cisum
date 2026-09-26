# PluginAudioDownload

Audio download plugin for Cisum. It automatically starts a download when the current track is missing a local file, gating work to the active music scene and avoiding duplicate/stale downloads.

## Functional Logic

- **Core responsibility**: Watch the current playback asset and, when it is missing locally and the music scene is active, kick off a download. It owns the gating policy and the view model that drives download lifecycle against the playback provider.
- **Key types / protocols**:
  - `AudioDownloadPlugin` — plugin entry (`AsyncSuperPlugin`, `SuperLog`), `id = "AudioDownloadPlugin"`, `order = 2`, `iconName = "icloud.and.arrow.down"`, `emoji = "⬇️"`, `policy = .disabled`.
  - `AudioDownloadRootView` / `AudioDownloadPluginRootView` — root view wrappers.
  - `AudioDownloadViewModel` — tracks the current asset and decides when to start/apply a download.
  - `AudioDownloadObserver` — subscribes to scene and playback events and forwards them to the view model.
  - `AudioDownloadRequestPolicy` — pure policy: whether to check the current asset, whether to start a download, and whether to apply a (possibly stale) download result.
  - `AudioDownloadPlaybackCapability` / `AudioDownloadPlaybackCapabilityAdapter` — narrows `PlaybackProviding`.
  - `AudioDownloadPluginInfo` — metadata (title, description, icon, order).
- **Plugin registration**: Registers with ID `AudioDownloadPlugin`. `onRegister` adds About/Manual docs. `onReadyAsync` resolves `SceneProviding` and `PlaybackProviding`, builds the playback capability adapter, the view model, and the observer. `addRootView(content:)` contributes the root view.
- **Workflow / data flow**:
  1. The observer receives scene and playback/asset-change events.
  2. `AudioDownloadRequestPolicy.shouldCheckCurrentAsset` only fires for an active music scene; a nil or already-present asset is ignored.
  3. `shouldStartDownload` prevents starting a duplicate active download for the same asset.
  4. `shouldApplyDownloadResult` only applies the result if the current asset has not changed (with symlinked-current-asset matching), and invalidates pending work after a scene deactivation (generation bump). Distinct dangling symlinks are not treated as the same asset.
- **Dependencies** (from `Package.swift`): `MagicKit`, `CisumUIComponents`, `MagicPlayMan`, `CisumKernelSupport`, `ProviderDocsView`, `ProviderScene`, `ProviderPlayback`. Resources: `Localizable.xcstrings`.

## Testing Logic

- **Test files**: `Tests/AudioDownloadPluginTests.swift`.
- **Key scenarios tested**:
  - Registration metadata: `iconName == "icloud.and.arrow.down"`, `order == 2`; music scene identifier `AppScene.music.rawValue == "Music Library"`.
  - `AudioDownloadRequestPolicy`: only starts for an active, missing asset; does not start a duplicate active download; does not restart after a successful download; applies results only to the current asset; stale results do not apply after scene deactivation; results apply for a symlinked current asset but not across distinct dangling symlinks.
  - ViewModel gating: inactive scene ignores asset changes; nil asset in the music scene is ignored; leaving the music scene bumps generation without crashing.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioDownload
  swift test
  ```
