# PluginPlayBack

The core playback plugin. It creates and owns the `MagicPlayMan` playback engine, registers it as the kernel's `PlaybackProviding`/`PlaybackMediaProviding`, and persists the last-played file per scene so playback state is restored across launches and scene switches.

## Functional Logic

- **Core responsibility:** Own the playback engine lifecycle, expose it to other plugins through the `PlaybackProviding` contract, and maintain a per-scene record of the last-played file on disk. It also contributes a "Current File" settings page showing recent playback by scene and live playback details.
- **Key types:**
  - `PluginPlayBack` — `@MainActor final class` conforming to `SuperPlugin`. `id = "PluginPlayBack"`, `order = 12`, category `.system`, policy `.alwaysOn`. Holds `magicPlayMan`, the `PlaybackProvider`, the `PlaybackStateStore`, and observers.
  - `PlaybackProvider` — concrete `PlaybackProviding` & `PlaybackMediaProviding` implementation that wraps `MagicPlayMan`, translates engine events (`onStateChanged`, `onCurrentURLChanged`, `onPlayModeChanged`, like/navigation events, time/duration notifications) into `PlaybackProvidingEvent`s, and exposes `makeMediaView()` / `localizedStateText(for:)`.
  - `PlaybackStateStore` — persists `<databaseRoot>/PluginPlayBack/current-playback.plist` as a `[sceneName: URLString]` dictionary, with one-time migration of the legacy global `"url"` key.
  - `PlaybackSceneObserver` — on scene change, loads that scene's last file (autoPlay off) or stops playback when the target scene has no history; uses a generation counter to ignore stale restores during rapid scene switches.
  - `PlaybackSettingsPlaybackObserver` / `PlaybackSettingsSceneObserver` — forward playback and scene events to the settings view model.
  - `PlaybackSettingsCapability` — internal protocol narrowing playback state (`currentURL`, `isPlaying`, `state`, `currentTime`, `duration`); `PlaybackSettingsCapabilityAdapter` adapts the provider (weakly held, with safe fallbacks).
  - `PluginPlayBackSettingsViewModel` — publishes current scene/URL/state/time/duration and reads per-scene last files from the store.
  - `PluginPlayBackSettingView` — settings UI listing recent playback per scene and a live playback details card.
  - Views: `PluginPlayBackAboutView`, `PluginPlayBackManualView`.
- **Plugin registration:** Registers as `PluginPlayBack`. `onBootAsync` creates `MagicPlayMan`, wraps it in `PlaybackProvider`, and registers both `PlaybackProviding` and `PlaybackMediaProviding`; it also builds the `PlaybackStateStore` from `StorageProviding.databaseRoot` and subscribes to `assetChanged` to record the current file. `onReadyAsync` creates the `PlaybackSceneObserver` (scene-aware restore) and installs the settings state. `onShutdownAsync` unregisters both providers and tears down observers.
- **Workflow/data flow:**
  1. Engine events flow through `PlaybackProvider` to observers (other plugins' observers + the scene/settings observers).
  2. When the asset changes, the URL is saved into the current scene's slot in the plist.
  3. On launch or scene switch, `PlaybackSceneObserver` restores that scene's last file (without auto-playing) or stops the engine if there is no history.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `MagicPlayMan`, `ProviderDocsView`, `ProviderPlayback`, `ProviderScene`, `ProviderStorage`. Platforms: macOS 14+, iOS 17+. Resources: `Resources`.

## Testing Logic

- **Test files:**
  - `Tests/PlaybackSettingsTests.swift` — uses a `PlaybackStub` and `SceneProviderStub` to test the capability adapter, settings view model, observers, and provider registration/unregistration.
  - `Tests/PlaybackStateStoreTests.swift` — exercises the plist persistence against a temporary directory.
- **Key scenarios tested:**
  - Capability adapter maps playback state and degrades safely after the playback stub is released.
  - Settings view model initializes from a capability, tracks scene/asset/state/time/duration events, and reads per-scene last files.
  - Playback and scene observers forward events and stop after cancellation; repeated cancel is idempotent.
  - Plugin boot registers both `PlaybackProviding` and `PlaybackMediaProviding`, and shutdown unregisters both.
  - `PlaybackStateStore` persists scene files independently, deletes the plist when all slots are cleared, migrates the legacy global `"url"` key exactly once, discards the legacy value on a scene-specific write, and returns `nil` for missing/malformed files (write failures do not escape).
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginPlayBack
  swift test
  ```
- Tests are thorough: they cover the real plist persistence and legacy migration, the observer wiring, and provider lifecycle, without booting a real audio engine.
