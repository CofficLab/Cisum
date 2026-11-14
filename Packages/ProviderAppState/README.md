# ProviderAppState

Defines the `AppStateProviding` protocol: the app-level UI state service that absorbs the legacy `AppVM` (Demo mode, database view visibility, import/drag-drop) and `StateVM` (status-message channel) responsibilities. The kernel resolves a conforming implementation via dependency injection.

## Functional Logic

- **Core responsibility**: app-level UI state — Demo mode, database view visibility, in-progress import/drag-drop flags, and the transient status-message channel.
- **Key protocol**: `AppStateProviding` (`@MainActor`, `AnyObject`, `ObservableObject`):
  - Properties: `isDemoMode`, `isDBViewVisible`, `isImporting`, `isDropping`, `hasDragOperation` (alias of `isDropping`), `stateMessage`.
  - Actions: `enterDemoMode()`, `exitDemoMode()`, `showDBView()`, `hideDBView()`, `closeDBView()`, `toggleDBView()`, `setImporting(_:)`, `setDragOperation(_:)`, `appendStateMessage(_:)`, `clearStateMessages()`.
  - Observation: `addObserver(_:)` returns an `AppStateProvidingObserverHandle`.
- **Events** (`AppStateProvidingEvent`): `.demoModeChanged(Bool)`, `.dbViewVisibilityChanged(Bool)`, `.importingChanged(Bool)`, `.droppingChanged(Bool)`, `.stateMessageChanged(String)`.
- **Provider pattern**: consumers call `kernel.resolveProvider((any AppStateProviding).self)`. The protocol provides a default `addObserver` implementation returning `NoopAppStateProvidingObserverHandle`, so lightweight stubs need no event machinery. `NoopAppStateProvidingObserverHandle.cancel()` is idempotent.
- **Dependencies**: none (Foundation only). Targets macOS 14+ / iOS 17+.

## Testing Logic

- **Test file**: `Tests/AppStateProvidingTests.swift`.
- **Key scenarios tested**:
  - A stub conforms to `AppStateProviding` and the default `addObserver` returns a `NoopAppStateProvidingObserverHandle` without invoking callbacks.
  - `NoopAppStateProvidingObserverHandle.cancel()` can be called repeatedly with no side effects.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderAppState
  swift test
  ```
- **Note**: this package is a protocol definition; tests verify protocol conformance with a stub and the no-op observer fallback.
