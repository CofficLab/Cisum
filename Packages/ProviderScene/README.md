# ProviderScene

Defines `SceneProviding` (the app-scene switching contract) and the fixed `AppScene` enum. Scenes are built into the provider (`Music Library`, `Audiobooks`) rather than contributed by plugins.

## Functional Logic

- **Core responsibility**: activate and persist the current app scene (e.g. Music Library vs. Audiobooks), independent of plugin UI aggregation.
- **Key types**:
  - `AppScene`: `String`-backed enum (`music = "Music Library"`, `audiobooks = "Audiobooks"`) — `CaseIterable, Sendable, Codable, Identifiable`. Exposes `displayName` (raw value, kept stable for persistence), `iconName` (`music.note.list` / `book.closed`), and `order` (0/1). Named `AppScene` to avoid clashing with `SwiftUI.Scene`.
  - `SceneProviding` (`@MainActor`, `AnyObject`, `ObservableObject`):
    - `var scenes: [AppScene] { get }` (fixed = `AppScene.allCases`).
    - `var currentScene: AppScene? { get }`.
    - `func setCurrentScene(_:)` — switch and persist.
    - `func restoreCurrentScene()` — restore from persistence, falling back to the first scene.
    - `addObserver(_:)` returns `SceneProvidingObserverHandle`.
- **Events** (`SceneProvidingEvent`): `.selectionChanged(scene: AppScene?)`.
- **Provider pattern**: consumers resolve via `kernel.resolveProvider((any SceneProviding).self)`. The default `addObserver` returns `NoopSceneProvidingObserverHandle`.
- **Dependencies**: `CisumKernelSupport` (`KernelCoreContainer` registration), `CisumUIComponents`.

## Testing Logic

- **Test file**: `Tests/SceneProvidingTests.swift`.
- **Key scenarios tested**:
  - `AppScene` keeps stable raw values, ids, display names, icon names, and order; encodes/decodes via JSON.
  - `KernelCoreContainer` resolves a registered `SceneProviding` and exposes `currentScene`/`scenes`.
  - Duplicate registration throws `KernelCoreError` until explicit `unregisterProvider`, then re-registration succeeds.
  - Default `addObserver` returns the no-op handle; `cancel()` is repeatable.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderScene
  swift test
  ```
- **Note**: provider package; tests pin the persisted enum values (so old UserDefaults/JSON still restore) and the kernel registration contract.
