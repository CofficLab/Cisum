# PluginBookPlayMode

The audiobook playback-mode plugin for Cisum. It restores the user's saved playback
mode (sequence / repeat-one / repeat-all / shuffle) when entering the audiobooks
scene and persists mode changes the user makes while the scene is active. It has no
visible UI of its own — it is a background behavior plugin.

## Functional Logic

- **Core responsibility:** synchronize the global `MagicPlayMode` with a persisted
  preference, but only while the app is in the audiobooks scene. Leaving the scene
  deactivates the plugin so it does not interfere with music playback.
- **Key types/protocols:**
  - `BookPlayModePlugin` — `AsyncSuperPlugin`, `SuperLog`; singleton `shared`,
    `id = "BookPlayModePlugin"`, `order = 7`, `iconName = "repeat"`,
    `policy = .disabled`, `category = .feature`.
  - `BookPlayModePluginInfo` — title "Book Play Mode", description "Book play mode
    management", `iconName = "repeat"`, `order = 7`.
  - `BookPlayModeViewModel` — `ObservableObject`; activates on `.audiobooks` and
    loads the stored mode (applying it only if it differs from the live mode);
    stores mode changes while active and shows an info alert naming the new mode;
    uses a generation counter to discard stale async work.
  - `BookPlayModeStore` — `actor` singleton; reads/writes the `bookPlayMode` key in
    both `UserDefaults.standard` and `NSUbiquitousKeyValueStore`;
    `resolvedPlayMode(localRawValue:cloudRawValue:)` prefers local, then cloud, then
    defaults to `.sequence`.
  - `BookPlayModePlaybackCapability` protocol (`playMode`, `setPlayMode(_:)`) +
    `BookPlayModePlaybackCapabilityAdapter` mapping `MagicPlayMode` to/from
    `PlaybackMode`.
  - `BookPlayModeObserver` — forwards scene `.selectionChanged` and playback
    `.playModeChanged` events to the view model.
  - `BookPlayModeRootView<Content>` / `BookPlayModePluginRootView` — passthrough root
    wrappers (no UI contribution of their own).
  - Closure types: `BookPlayModeLoadAction`, `BookPlayModeStoreAction`.
- **Plugin registration:** registered as `BookPlayModePlugin`. In `onRegister` it adds
  About/Manual docs. `onBootAsync` only keeps a weak kernel reference.
  `onReadyAsync` / `onEnable` build the view model and observer; `onDisable` /
  `onShutdownAsync` tear them down. `addRootView(content:)` simply wraps the content.
- **Workflow/data flow:** enter `.audiobooks` → view model activates → loads stored
  mode → if it differs from the live playback mode, calls `setPlayMode`. While
  active, a playback `.playModeChanged` event → view model stores the new mode to
  UserDefaults/iCloud and alerts the user. Leave the scene → generation bumps,
  deactivation prevents further saves/restores.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `MagicPlayMan`,
  `CisumKernelSupport`, `ProviderDocsView`, `ProviderScene`, `ProviderPlayback`.

## Testing Logic

- **Test files:**
  - `Tests/BookPlayModeCoverageTests.swift` — probe-based store, view-model, adapter
    and observer tests.
  - `Tests/BookPlayModePluginTests.swift` — metadata and store-resolution edge cases.
- **Key scenarios tested:**
  - `BookPlayModeStore.resolvedPlayMode`: prefers local, falls back to cloud,
    defaults to `.sequence` for missing or bogus values.
  - Store round-trip: `storePlayMode` then `getPlayMode` returns the same mode.
  - ViewModel: entering the target scene activates and restores a stored mode;
    leaving deactivates (no `setPlayMode`); skips applying when stored mode already
    matches; active mode changes are persisted; inactive changes are ignored.
  - Adapter: maps `playMode` raw values and forwards `setPlayMode`.
  - Observer: scene events drive activation/deactivation; playback mode events reach
    the view model; cancellation stops further updates.
  - Metadata: `iconName == "repeat"`, `order == 7`; invalid local value falls back
    to cloud; both invalid fall back to sequence.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBookPlayMode
  swift test
  ```
