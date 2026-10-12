# ProviderControlView

Defines `ControlViewProviding` (the top playback control area contract) plus `DefaultControlViewProvider` and the composed `ControlView` / `StateView` SwiftUI views. Each sub-block (hero, status, progress, buttons, right album) can be independently injected; uninjected blocks fall back to defaults or are omitted.

## Functional Logic

- **Core responsibility**: let the host assemble the root-layout top playback control strip — hero/cover, status message, progress, transport buttons, right album — by injecting each sub-view separately, and render the resulting `ControlView`.
- **Key types**:
  - `ControlViewProviding` (`@MainActor`, `AnyObject`, `ObservableObject`):
    - `func makeControlView() -> AnyView`.
    - `func setHeroView(_:)`, `setStateView(_:)`, `setProgressView(_:)`, `setControlButtonsView(_:)`, `setRightAlbumView(_:)` — each takes `AnyView?` (nil resets to default / omits).
    - `func setDemoMode(_:)`.
  - `DefaultControlViewProvider`: stores the injected `AnyView?` slots and `isDemoMode`; initializable with `stateViews`/`stateMessage` closures that feed the default `StateView`.
  - `ControlView`: `GeometryReader`-based layout that sizes the hero area to whatever height remains after status/progress/buttons; only renders sub-areas that have been injected.
  - `StateView`: shows the info pill plus contributed state views; suppressed entirely in Demo mode.
- **Events** (`ControlViewProvidingEvent`): `.viewInvalidated`.
- **Dependencies**: `CisumUIComponents` (theme tokens, `CisumPlayerLayout` metrics).

## Testing Logic

- **Test file**: `Tests/ControlViewProviderTests.swift`.
- **Key scenarios tested**:
  - `DefaultControlViewProvider` starts with all sub-views nil and Demo mode off; each `setXxxView`/`setDemoMode` round-trips; passing `nil` clears the slot; `makeControlView()` builds.
  - `StateView` suppresses messages and contributed views in Demo mode (message/state closures are only invoked once across non-empty configurations).
  - A lightweight stub ignores injected views and returns a no-op observer handle.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderControlView
  swift test
  ```
- **Note**: tests verify slot storage and the `StateView` Demo-mode gating; actual player visuals come from plugin-injected views.
