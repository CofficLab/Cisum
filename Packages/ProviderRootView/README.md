# ProviderRootView

Defines `RootViewProviding` (the root layout injection contract), `RootOverlayItem`, and the default `DefaultRootViewProvider` + `RootLayoutView` that assemble the app's root window layout (control area + content area + status area + toolbar, with plugin overlays).

## Functional Logic

- **Core responsibility**: let the host inject each region of the root layout (top control strip, main content, bottom status, toolbar) and wrap the composed root view with plugin overlays, then render `RootLayoutView`.
- **Key types**:
  - `RootOverlayItem`: `@MainActor Identifiable` with `id: String`, `order: Int`, and a `wrap: (AnyView) -> AnyView` closure — plugins wrap the existing root view without knowing its internals.
  - `RootViewProviding` (`@MainActor`, `AnyObject` — note: *not* `ObservableObject`; state changes broadcast via events):
    - Overlays: `var overlays: [RootOverlayItem]`, `addOverlays(_:)` (dedup by id, sort by order), `removeOverlays(ids:)`.
    - Region injection: `setControlView(_:)`, `setContentView(_:)`, `setStatusView(_:)`, `setToolbarContent(_:)` (nil resets/defaults).
    - Content visibility: `isContentViewVisible`, `setContentViewVisible(_:)`, `showContentView()`, `hideContentView()`, `toggleContentView()`.
    - `makeRootView() -> AnyView` — composes `RootLayoutView` then applies each overlay's `wrap`.
  - `DefaultRootViewProvider`: holds the injected `AnyView?` slots, uses `KernelEventObserverStore` to broadcast events, and sorts overlays by order.
  - `RootLayoutViewModel`: subscribes to provider events and mirrors slots into `@Published` properties for SwiftUI (decouples the provider from `ObservableObject`).
  - `RootLayoutView`: `GeometryReader` layout that expands/collapses between the mini-player height and the full content height; queries `PluginProviding` directly for toolbar buttons and status views; resizes the macOS window on content visibility changes.
  - `ContentPlaceholderView`: fallback when no content is injected.
- **Events** (`RootViewProvidingEvent`): `.controlViewChanged`, `.contentViewChanged`, `.statusViewChanged`, `.toolbarContentChanged`, `.contentViewVisibilityChanged`, `.overlaysChanged`.
- **Dependencies**: `MagicKit` (`SuperLog`), `CisumKernelSupport` (`KernelCoreContainer`, `KernelEventObserverStore`), `CisumUIComponents` (`LumiUIThemeRegistry`, `CisumPlayerLayout`), `ProviderPlayback`.

## Testing Logic

- **Test file**: `Tests/DefaultRootViewProviderTests.swift`.
- **Key scenarios tested**:
  - `ContentPlaceholderView` body builds without injected content.
  - Each `setXxxView` / `setContentViewVisible` / show/hide/toggle sequence publishes the expected ordered events; canceling the observer stops further events.
  - `RootLayoutViewModel` mirrors provider state and ignores `.overlaysChanged` (it doesn't re-render overlays).
  - `addOverlays` dedupes by id, sorts by order, and only broadcasts on actual changes; `removeOverlays` triggers another event; `makeRootView()` applies wraps in order.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderRootView
  swift test
  ```
- **Note**: tests cover the default provider's event/overlay semantics and view-model mirroring; window resizing is macOS-specific and not asserted.
