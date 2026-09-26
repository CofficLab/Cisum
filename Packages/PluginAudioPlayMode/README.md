# PluginAudioPlayMode

Audio play-mode plugin for Cisum. It manages playback modes (sequence, repeat-all, loop, shuffle), persists the selected mode, and re-sorts or re-shuffles the queue when the mode changes.

## Functional Logic

- **Core responsibility**: Track and persist the current play mode, restore it when the music scene becomes active, and reorder the queue (sorted order or shuffled order) whenever the user switches mode.
- **Key types / protocols**:
  - `AudioPlayModePlugin` — plugin entry (`AsyncSuperPlugin`, `SuperLog`), `id = "AudioPlayModePlugin"`, `order = 0`, `iconName = "repeat"`, `emoji = "🔄"`, `policy = .disabled`.
  - `AudioPlayModeViewModel` — holds the active mode, applies it to the playback capability, and triggers sort/shuffle.
  - `AudioPlayModeObserver` — forwards scene/playback events to the view model.
  - `AudioPlayModeStore` — persistent store for the play mode (local value with cloud fallback; available modes are sequence, repeatAll, loop, shuffle).
  - `AudioPlayModeRootView` / `AudioPlayModePluginRootView` — UI.
  - `AudioPlayModePlaybackCapability` / `Adapter` — narrows `PlaybackProviding`.
  - `AudioPlayModePluginInfo` — metadata.
- **Plugin registration**: Registers with ID `AudioPlayModePlugin`. `onReadyAsync` resolves `SceneProviding` and `PlaybackProviding`, then builds the view model with closures: a `sort` action and `shuffle` action backed by `AudioLibraryOrderingProviding`, and load/store actions backed by `AudioPlayModeStore`. `addRootView(content:)` contributes the root view.
- **Workflow / data flow**:
  1. When the music scene becomes active, the stored mode is resolved (local value preferred, cloud fallback, defaulting to sequence) and pushed to the playback capability — skipped if it already matches.
  2. Switching to sequence re-sorts the queue around the current URL; switching to shuffle shuffles it; loop only stores the mode without reordering.
  3. Mode changes are ignored while the plugin is inactive (non-music scene); sort errors are logged and surfaced without crashing.
- **Dependencies** (from `Package.swift`): `MagicKit`, `CisumUIComponents`, `ProviderAudioLibrary`, `MagicPlayMan`, `CisumKernelSupport`, `ProviderDocsView`, `ProviderScene`, `ProviderPlayback`. Resources: `Localizable.xcstrings`.

## Testing Logic

- **Test files**:
  - `Tests/AudioPlayModePluginTests.swift` — registration metadata and fallback defaults.
  - `Tests/AudioPlayModeCoverageTests.swift` — store resolution and view-model behavior.
- **Key scenarios tested**:
  - Metadata: `iconName == "repeat"`, `emoji == "🔄"`, `order == 0`.
  - `AudioPlayModeStore.resolvedPlayMode`: prefers the local value, falls back to cloud, defaults to sequence when both are missing; falls back to cloud when the local value is invalid.
  - Store round-trip: store/get a mode, invalid stored raw value falls back to sequence, reset restores default, available modes are exactly `[.sequence, .repeatAll, .loop, .shuffle]`.
  - `AudioPlayModeViewModel`: entering the target scene activates and restores the stored mode; leaving deactivates and returning reactivates; skips pushing when the stored mode already matches; switching to sequence sorts the queue and stores; switching to shuffle shuffles; loop only stores; inactive mode changes are ignored; sort errors are handled gracefully.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioPlayMode
  swift test
  ```
