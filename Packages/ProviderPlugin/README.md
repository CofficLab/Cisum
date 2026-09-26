# ProviderPlugin

Compatibility facade. Plugin contracts (`PluginMetadata`, `SuperPlugin`, `PluginProviding`, etc.) now live in `CisumKernelSupport` (matching Lumi). This package simply re-exports them so legacy `import ProviderPlugin` call sites keep compiling.

## Functional Logic

- **Core responsibility**: preserve source compatibility for code that used to import the Provider-package plugin contracts; the actual contracts are defined in `CisumKernelSupport`.
- **Key content**: `Sources/ProviderPlugin/Exports.swift` contains a single line:
  ```swift
  @_exported import CisumKernelSupport
  ```
  This makes every public symbol from `CisumKernelSupport` visible when consumers `import ProviderPlugin`.
- **Dependencies**: `CisumKernelSupport`.

## Testing Logic

- **Test file**: `Tests/ProviderPluginExportsTests.swift`.
- **Key scenarios tested**:
  - A `PluginMetadata` can be constructed (id/name/description/policy) and its fields round-trip — proving the re-export exposes the kernel contracts.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderPlugin
  swift test
  ```
- **Note**: this package is a pure re-export; there is no protocol or logic of its own.
