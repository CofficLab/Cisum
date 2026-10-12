# Package architecture

Cisum follows the same package model as Lumi and Kuzee and uses the pinned shared
`LumiKernel`. Application packages have four roles:

1. `Kit*` packages contain reusable foundations that are not owned by one feature:
   playback primitives, UI components, event observation, and app utilities.
2. `Provider*` packages define app-facing contracts, domain models, events, and
   observer handles. A Provider contract is the boundary used by the kernel's
   registry; it is not duplicated as a narrower capability protocol in each plugin.
3. `Plugin*` packages implement one feature and consume other features through
   their Provider contracts. A plugin can provide the concrete implementation for
   a service it owns, then register that implementation with the shared kernel.
4. `FactoryCisum` is the sole composition root. It selects and assembles the
   app's providers and plugins with the shared kernel; feature plugins must not
   depend on one another's implementation packages.

The package graph should therefore stay within these roles:

```text
FactoryCisum
  ├── Plugin*  ── consumes ──> Provider*
  ├── Provider* ── uses ─────> Kit*
  └── Kit*
```

Avoid per-plugin `Capability` protocols and adapters that only forward calls to a
Provider, app-wide compatibility/export aggregators, duplicate domain models, and
`NotificationCenter` shims where the owning Provider already exposes typed events.
Put a shared contract in the appropriate `Provider*` package, shared presentation
or utility in `Kit*`, feature behavior in `Plugin*`, and app-only assembly in
`FactoryCisum`.

Some platform integration is legitimate when the system API has no SwiftUI-native
equivalent—for example, AppKit window sizing. Keep that code narrow and at the
platform boundary; do not use it to bridge duplicate Kernel/UI APIs.

## Cross-feature contracts

- `ProviderPlayback` owns the shared `PlaybackMode`, playback state, snapshots,
  commands, events, and observer contract. `KitPlayback` adds playback-engine and
  presentation behavior without defining another mode enum.
- `ProviderStorage` owns `StorageLocation` and `StorageProvidingEvent`; the storage
  implementation belongs to its owning plugin and consumers subscribe through the
  Provider rather than app-wide storage notifications.
- Other cross-feature data and events live in their corresponding `Provider*`
  packages. The feature that owns persistence or file synchronization remains
  responsible for that lifecycle.

Architecture checks and package graph verification should accompany changes to
these boundaries. Do not treat historical design notes as current contracts when
the source graph has since migrated.
