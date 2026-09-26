# ProviderContentView

Defines `ContentViewProviding` (the main content-area tab contract) plus a default implementation `DefaultContentViewProvider` and the `ContentAreaView` / `EmptyTabView` SwiftUI views it renders.

## Functional Logic

- **Core responsibility**: let the host inject plugin-contributed tabs into the main content area and render them as a tab strip (macOS top strip, iOS system tab view, or a custom segmented control in Demo mode).
- **Key types**:
  - `ContentTabItem`: `Identifiable` value type with `id: String`, `title: String`, `order: Int`, `content: AnyView`.
  - `ContentViewProviding` (`@MainActor`, `AnyObject`, `ObservableObject`):
    - `var tabs: [ContentTabItem] { get }` (sorted by `order`).
    - `func setTabs(_:)` — replaces tabs and broadcasts `.tabsChanged(ids:)`.
    - `func setDemoMode(_:)` — explicit Demo-mode input (not via SwiftUI environment).
    - `func makeContentView() -> AnyView`.
  - `DefaultContentViewProvider`: `@Published` tabs/demo mode; internal `ContentViewObserverStore` that snapshots callbacks before dispatch so an observer cancelling itself mid-delivery doesn't skip siblings.
  - `ContentAreaView`: renders a single tab directly when there's only one; otherwise a macOS top tab strip (`ViewThatFits` + horizontal scroll), an iOS `TabView`, or a custom button strip in Demo mode; falls back to `EmptyTabView` when no tabs exist.
- **Events** (`ContentViewProvidingEvent`): `.tabsChanged(ids: [String])`.
- **Dependencies**: `CisumUIComponents` (theme tokens via `@LumiTheme`).

## Testing Logic

- **Test file**: `Tests/ContentViewProviderTests.swift`.
- **Key scenarios tested**:
  - `setTabs(_:)` sorts by `order` and publishes sorted identifiers; clearing tabs publishes an empty list.
  - An observer cancelling itself during delivery does not skip other observers.
  - `setDemoMode` flips `isDemoMode`; `makeContentView()` and `ContentAreaView`/`EmptyTabView` bodies can be constructed in both populated and empty states.
  - A lightweight stub gets safe no-op defaults for `setDemoMode`/`addObserver`.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderContentView
  swift test
  ```
- **Note**: tests cover the default provider's sorting, observer-dispatch semantics, and view body construction; they do not exercise real plugin content.
