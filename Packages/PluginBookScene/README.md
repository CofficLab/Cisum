# PluginBookScene

The audiobook scene plugin for Cisum. It contributes the decorative bookshelf
"poster" shown on the home screen and wires its "Enter Audiobook Library" button to
switch the app into the built-in `.audiobooks` scene.

## Functional Logic

- **Core responsibility:** provide the entry point into the audiobook feature. The
  scene itself is a fixed `AppScene.audiobooks` value owned by `ProviderScene`; this
  plugin only contributes the poster view and the action that switches to it.
- **Key types/protocols:**
  - `BookScenePlugin` — `AsyncSuperPlugin`, `SuperLog`; singleton `shared`,
    `id = "BookScenePlugin"`, `order = 0`, `iconName = "book.closed"`,
    `category = .core`, `policy = .disabled`.
  - `BookScenePluginInfo` — title "Audiobook Scene", description "Provides audiobook
    scene", `iconName = "book.closed"`, `order = 0`.
  - `BookScenePluginPosterView` — wires the enter action to
    `scene.setCurrentScene(.audiobooks)`.
  - `BookPosterView` — public decorative view: a horizontal scrolling row of
    gradient book spines (sample titles) over a bookshelf base, plus an "Enter
    Audiobook Library" button.
  - Closure types: `BookSceneEnterAction`, `BookSceneDismissAction`.
- **Plugin registration:** registered as `BookScenePlugin`. In `onRegister` it adds
  About/Manual docs. In `onBootAsync` it calls
  `PluginContributionProviding.addPosterView`. `onReadyAsync` / `onEnable` resolve
  `SceneProviding` and store a `setSceneAction` closure that calls
  `setCurrentScene(.audiobooks)`. `onDisable` clears the action; `onShutdownAsync`
  removes contributions. `addPosterView()` always returns a non-nil view (falling
  back to a no-op action if the scene provider is not yet available).
- **Workflow/data flow:** home screen shows the poster → user taps "Enter Audiobook
  Library" → `setSceneAction(.audiobooks)` → `SceneProviding` switches the app scene,
  which activates the other book plugins (controls, progress, like, play mode,
  repository view).
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`,
  `ProviderDocsView`, `ProviderScene`.

## Testing Logic

- **Test files:**
  - `Tests/BookScenePluginCoverageTests.swift` — kernel-lifecycle tests using a
    `SceneProbe`.
  - `Tests/BookScenePluginTests.swift` — metadata assertions.
- **Key scenarios tested:**
  - `onRegister` with no docs provider registered does not crash.
  - `onReady` without a scene provider keeps a safe fallback (poster still returned).
  - With a scene provider registered, `onReady` installs the scene action and tapping
    the poster calls `setCurrentScene(.audiobooks)` (incrementing the probe's
    `setSceneCount`).
  - `onEnable` reinstalls the action after `onDisable`; `onShutdown` clears it while
    still returning a poster view.
  - Metadata: name/description/icon/order match `BookScenePluginInfo`
    (`iconName == "book.closed"`, `order == 0`).
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBookScene
  swift test
  ```
