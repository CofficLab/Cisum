# PluginRootView

Cisum's root-view plugin and player layout. It reuses the `RootViewProviding`
contract and state from LumiProviders, while composing those contributions into
Cisum's player-specific layout.

`RootViewPlugin` registers the provider during Kernel boot and removes it
during shutdown. FactoryCisum installs it before feature plugins so those
plugins can contribute root overlays during their own startup.

## Source layout

- `RootViewPlugin.swift` — plugin metadata and provider lifecycle.
- `Providers/RootViewProvider.swift` — shared `DefaultRootViewProviding` adapter.
- `Views/RootLayoutView.swift` — player, content, status, and window layout.
- `Views/RootOverlayHostView.swift` — applies dynamically contributed overlays.
- `Views/ContentPlaceholderView.swift` — empty content placeholder.
- `ViewModels/RootLayoutViewModel.swift` — observes toolbar and status contributions.
