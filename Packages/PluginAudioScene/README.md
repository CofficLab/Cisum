# PluginAudioScene

Music scene / poster plugin for Cisum. It contributes the poster (cover-art) view used to enter the music scene and wires taps to switch the current scene to `.music`.

## Functional Logic

- **Core responsibility**: Provide the visual poster entry point for the music scene and the action that switches the active scene to `AppScene.music`. The music scene itself is a fixed built-in enum owned by `ProviderScene`; this plugin does not register new scenes.
- **Key types / protocols**:
  - `AudioScenePlugin` — plugin entry (`AsyncSuperPlugin`, `SuperLog`), `id = "AudioScenePlugin"`, `order = 0`, `iconName = "music.note.list"`, `category = .core`, `policy = .disabled`.
  - `AudioScenePluginPosterView` — the poster view with a `setCurrentScene` closure.
  - `AudioPosterView` — the underlying poster artwork view.
  - `AudioScenePluginInfo` — metadata (title, description, icon, order).
  - About/Manual docs views.
- **Plugin registration**: Registers with ID `AudioScenePlugin`. `onBootAsync` contributes `addPosterView()` via `PluginContributionProviding`. `onReadyAsync` resolves `SceneProviding` and installs a `setSceneAction` closure that calls `scene.setCurrentScene(_:)`.
- **Workflow / data flow**:
  1. At boot the poster view is contributed (always non-nil).
  2. At ready/enable, the scene action is installed: tapping the poster calls `setCurrentScene(.music)` on the resolved `SceneProviding`.
  3. If no scene provider is available, the poster falls back to a no-op closure so it still renders without crashing.
  4. `onDisable` clears the action back to the fallback; `onShutdownAsync` removes its contribution and clears the action.
- **Dependencies** (from `Package.swift`): `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `ProviderDocsView`, `ProviderScene`. Resources: `Localizable.xcstrings`.

## Testing Logic

- **Test files**:
  - `Tests/AudioScenePluginTests.swift` — registration metadata.
  - `Tests/AudioScenePluginCoverageTests.swift` — plugin lifecycle.
- **Key scenarios tested**:
  - Metadata: `AudioScenePluginInfo.iconName == "music.note.list"`, `order == 0`.
  - Lifecycle: `onRegister` without docs is safe; `onReady` without a scene provider keeps a no-op fallback (poster still returned); `onReady` installs the scene action when the provider is registered (tapping switches the scene); `onEnable` reinstalls the action after `onDisable`; `onShutdown` clears the action; metadata matches the plugin's `metadata`/`iconName`/`order`.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioScene
  swift test
  ```
