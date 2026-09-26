# PluginToast

A core plugin that provides global transient toasts, loading indicators, and modal error notices. It registers itself as the kernel's `ToastProviding` service and overlays a global toast layer on the root view.

## Functional Logic

- **Core responsibility:** Present top-of-screen toast messages (auto-dismissed), indeterminate loading cards, and a centered, dismissible error dialog (with copy-to-clipboard) over the entire app UI.
- **Key types:**
  - `ToastPlugin` — `@MainActor final class` conforming to `SuperPlugin`. `id = "ToastPlugin"`, `order = 10`, icon `"bell.badge"`, category `.core`, policy `.alwaysOn`. Holds the `center = ToastProvider()`.
  - `ToastProvider` — `@MainActor final class` conforming to `ObservableObject, ToastProviding`. Publishes `currentToast`, `currentError`, `currentLoading`; implements `show(_:)` (auto-dismiss after an optional duration, default 3 s), `presentError(title:message:)`/`dismissError()`, `showLoading(title:detail:)`/`dismissLoading()`, and `dismissAll()`.
  - `ToastOverlay<Content>` — public view that overlays the content with a top toast/loading card and a centered error dialog; also exposes the `View.withToastOverlay(center:)` modifier. Internal `ToastCard`, `LoadingCard`, and `ErrorNoticeOverlay` render the material-styled cards.
- **Plugin registration:** Registers as `ToastPlugin`. `onBootAsync` unregisters any existing `ToastProviding`, registers `center`, installs `CisumToastBridge`, and adds a root overlay (`id: "cisum.toast"`, order 10000) via `RootViewProviding.addOverlays`. `onShutdownAsync` dismisses everything, removes the overlay, and restores a `DefaultToastProvider` bridge.
- **Workflow/data flow:**
  1. Any code calls `ToastProviding.show(...)` / `presentError` / `showLoading`.
  2. The provider updates its published state; `ToastOverlay` renders the corresponding card with spring animations.
  3. Toasts auto-dismiss after their duration; errors persist until closed; new toasts cancel pending dismissals and clear loading.
- **Dependencies:** `MagicKit`, `CisumKernelSupport`, `ProviderRootView`, `ProviderToast`. Platforms: macOS 14+, iOS 17+. Resources: `Resources`.

## Testing Logic

- **Test files:**
  - `Tests/PluginToastTests/PluginToastTests.swift` — XCTest-based; covers provider behavior and plugin registration/overlay wiring.
  - `Tests/PluginToastTests/ToastProviderCoverageTests.swift` — Swift Testing; covers provider state transitions in detail.
- **Key scenarios tested:**
  - `show` replaces the current toast; zero-duration toasts stay visible; positive-duration toasts auto-dismiss.
  - Showing a toast clears an active loading card; showing loading clears the toast; error presentation/dismissal; `dismissAll` clears everything.
  - A new toast cancels the previous toast's pending dismissal timer.
  - Plugin boots: `center` is registered as `ToastProviding`, the root overlay id is `cisum.toast`, and shutdown removes the overlay.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginToast
  swift test
  ```
- Tests cover the provider's state machine and lifecycle registration; the visual layout is not asserted.
