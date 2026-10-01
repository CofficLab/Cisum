# ProviderPlugin

Provider-layer contracts and the host-side registry for Cisum plugin UI contributions.

## Functional Logic

- **Core responsibility**: own `PluginProviding`, `PluginContributionProviding`, their presentation item model, and `PluginContributionService`.
- **Dependencies**: `KernelCore`, `CisumUIComponents`, and `KitEventObservation`.

## Testing Logic

- **Test file**: `Tests/ProviderPluginExportsTests.swift`.
- **Key scenarios tested**:
  - A plugin setting navigation item preserves its stable identity, title, and order.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderPlugin
  swift test
  ```
- **Note**: generic kernel plugin contracts remain owned by `LumiKernel`; Cisum-specific UI contribution APIs are owned here.
