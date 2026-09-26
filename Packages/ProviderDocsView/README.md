# ProviderDocsView

Defines `DocsViewProviding` (the "About / Manual" contribution contract) and `DocsEntry`, plus a `DefaultDocsViewProvider` that hosts plugin-contributed documentation entries.

## Functional Logic

- **Core responsibility**: let each plugin register its own About page and user-manual entry during `onRegister`; the host later surfaces them in Settings → General → Manual and in plugin-management detail views.
- **Key types**:
  - `DocsEntry`: `@MainActor Identifiable` value type with `id: String`, `name: String`, and a `makeView: @MainActor () -> AnyView` closure (built lazily via `@ViewBuilder`).
  - `DocsViewProviding` (`@MainActor`, `AnyObject`, `ObservableObject`):
    - `var aboutEntries: [DocsEntry] { get }`, `var manualEntries: [DocsEntry] { get }`.
    - `replaceAboutEntries(_:)`, `replaceManualEntries(_:)`.
    - `addAbout(_:)`, `addManual(_:)` — append semantics, dedup by `id` (first registration wins); default protocol extensions implement these on top of the replace methods.
    - `removeEntries(id:)` — strips the id from both about and manual lists.
  - `DefaultDocsViewProvider`: `@Published` arrays; thread-safe-ish main-actor storage; implements the replace methods directly.
- **Provider pattern**: plugins resolve `DocsViewProviding` from the kernel at registration time and call `addAbout`/`addManual`. The kernel's `KernelCoreContainer` enforces single registration (duplicate registration throws `KernelCoreError`).
- **Dependencies**: `CisumKernelSupport` (kernel container), `CisumUIComponents`.

## Testing Logic

- **Test file**: `Tests/DocsViewProvidingTests.swift`.
- **Key scenarios tested**:
  - `addAbout`/`addManual` append and dedup by id; `removeEntries(id:)` strips both kinds.
  - `replaceAboutEntries`/`replaceManualEntries` fully replace both collections.
  - `DocsEntry.makeView()` builds its view lazily (build counter increments only on first call).
  - `KernelCoreContainer` registers and resolves the provider, and rejects a duplicate registration while keeping the first instance.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderDocsView
  swift test
  ```
- **Note**: tests cover the default provider's append/dedup/remove semantics and the kernel registration contract.
