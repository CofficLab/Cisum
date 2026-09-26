# PluginScene

The scene provider plugin. It registers the kernel's `SceneProviding` service, persists the current scene to disk, restores it on launch, and contributes a toolbar scene switcher plus a Scene settings entry. Scenes are a fixed built-in enum (e.g. music library, audiobooks).

## Functional Logic

- **Core responsibility:** Own the current `AppScene` selection, persist it across launches, broadcast scene changes, and provide UI to switch scenes. It boots early (before storage is ready) and attaches persistence in a second phase.
- **Key types:**
  - `ScenePlugin` — `@MainActor final class` conforming to `AsyncSuperPlugin, SuperLog`. `id = "ScenePlugin"`, `metadata.id = "scene"`, `order = 9999`, icon `"rectangle.3.group"`, category `.core`, policy `.alwaysOn`.
  - `SceneProvider` — `@MainActor final class` conforming to `ObservableObject, SceneProviding`. Exposes `scenes = AppScene.allCases`, `currentScene`, `setCurrentScene(_:)`, `restoreCurrentScene()`, and observer registration. Persists to `<pluginDataDirectory>/current-scene.json`; supports two-phase init (`init()` then `enablePersistence(pluginDataDirectory:)`) so the instance identity stays stable before storage is ready.
  - `SceneSettingsCapability` — internal protocol narrowing scene state to `scenes`, `currentScene`, `setCurrentScene(_:)`; `SceneSettingsCapabilityAdapter` adapts the provider (weakly held).
  - `SceneProvidingObserver` — forwards provider changes to the view model, performing an initial sync before installing the listener.
  - `SceneSettingsViewModel` — `ObservableObject` publishing `scenes` and `currentScene`, with `select(_:)` and `currentSceneIconName`.
  - `SceneSwitcher` — toolbar button + popover listing scenes via `ScenePosterView` entries.
  - `ScenePosterView` — poster card for a single scene (icon, title, description, enter button).
  - Views: `SceneSettingsView`, `ScenePluginAboutView`, `ScenePluginManualView`.
- **Plugin registration:** Registers as `ScenePlugin`. `onBootAsync` registers a persistence-free `SceneProvider` as `SceneProviding` (so dependent plugins can resolve it immediately) and contributes the toolbar switcher. `onReadyAsync` (after storage is up) calls `enablePersistence(pluginDataDirectory:)` on the same instance, restores the saved scene, and assembles the settings view model/observer. `onShutdownAsync` unregisters the provider.
- **Workflow/data flow:**
  1. On boot, an in-memory `SceneProvider` is registered; on ready, the disk directory is attached and the saved scene is restored (falling back to the first scene).
  2. `setCurrentScene` persists the selection to JSON and notifies observers (including `PluginPlayBack`, which restores per-scene playback).
  3. The toolbar switcher and settings view both drive `setCurrentScene`.
- **Dependencies:** `MagicKit`, `CisumKernelSupport`, `ProviderDocsView`, `CisumUIComponents`, `ProviderScene`. Platforms: macOS 14+, iOS 17+. Resources: `Resources`.

## Testing Logic

- **Test files:**
  - `Tests/PluginSceneTests/ScenePluginTests.swift` — provider registration, persistence, observer/view-model wiring, and plugin boot ordering.
  - `Tests/PluginSceneTests/SceneSettingsTests.swift` — view model and capability adapter against a `SceneProbe`.
- **Key scenarios tested:**
  - Provider registers/unregisters as `SceneProviding`; the settings navigation item has id `"scene"`, title `"Scene"`, icon `"rectangle.3.group"`.
  - A scene-dependent probe plugin boots successfully after `ScenePlugin` (provider available).
  - Scenes are the fixed built-in list (`[.music, .audiobooks]`).
  - Current scene persists to `current-scene.json` and restores across instances; unknown persisted scenes fall back to `.music`; observers are notified on change and stop after cancellation.
  - Observer performs initial sync, forwards events, and stops after cancel.
  - ViewModel loads scenes/current state, delegates `select`, and refreshes on `handleProviderChanged`; the adapter degrades after the probe is released.
  - Plugin assembly survives enable/disable cycles and reuses the long-lived view model.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginScene
  swift test
  ```
- Tests are thorough: they cover real JSON persistence, legacy UserDefaults fallback, observer cancellation, and boot ordering.
