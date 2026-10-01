# PluginRootView

Cisum's root-view plugin and player layout. It reuses the `RootViewProviding`
contract and state from LumiProviders, while composing those contributions into
Cisum's player-specific layout.

`CisumRootViewPlugin` registers the provider during Kernel boot and removes it
during shutdown. FactoryCisum installs it before feature plugins so those
plugins can contribute root overlays during their own startup.

## Source layout

- `CisumRootViewPlugin.swift` — plugin metadata and provider lifecycle.
- `Providers/CisumRootViewProvider.swift` — shared `DefaultRootViewProviding` adapter.
- `Views/CisumRootLayoutView.swift` — player, content, status, and window layout.
- `Views/CisumRootOverlayHostView.swift` — applies dynamically contributed overlays.
- `Views/CisumContentPlaceholderView.swift` — empty content placeholder.
- `ViewModels/CisumRootLayoutViewModel.swift` — observes toolbar and status contributions.
