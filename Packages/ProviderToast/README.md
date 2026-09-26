# ProviderToast

Defines the `ToastProviding` protocol plus the value types it presents (`CisumToast`, `CisumErrorNotice`, `CisumLoadingNotice`, `CisumToastStyle`) and a no-op `DefaultToastProvider`.

## Functional Logic

- **Core responsibility**: a lightweight banner/notification surface for transient info messages, error notices, and loading indicators, decoupled from any specific presentation mechanism.
- **Key types**:
  - `ToastProviding` (`@MainActor`, `AnyObject`):
    - `func show(_ toast: CisumToast)`.
    - `func presentError(title:message:)`, `func dismissError()`.
    - `func showLoading(title:detail:)`, `func dismissLoading()`.
    - `func dismissAll()`.
    - Default convenience: `show(_:detail:style:duration:)` builds a `CisumToast` and forwards to `show(_:)`.
  - `CisumToast`: `Sendable, Equatable` — `title`, `detail: String?`, `style: CisumToastStyle`, `duration: TimeInterval?`.
  - `CisumToastStyle`: `.info`, `.success`, `.warning`, `.error`.
  - `CisumErrorNotice`: `Identifiable, Sendable, Equatable` — `id: UUID`, `title`, `message`.
  - `CisumLoadingNotice`: `Sendable, Equatable` — `title`, `detail: String?`.
  - `DefaultToastProvider`: `@MainActor` no-op implementation (all methods are empty) for pre-presentation bootstrapping / tests.
- **Dependencies**: none (Foundation only).

## Testing Logic

- **Test file**: `Tests/ProviderToastTests/ProviderToastTests.swift` (XCTest, not Swift Testing).
- **Key scenarios tested**:
  - `CisumToast` value equality.
  - The convenience `show(_:detail:style:duration:)` forwards all options into a `CisumToast` captured by a `ToastSpy`.
  - `CisumErrorNotice` preserves its `id`/equality; `CisumLoadingNotice` allows a nil detail; new error notices get fresh UUIDs.
  - `CisumToastStyle` raw values are stable.
  - `DefaultToastProvider` absorbs all calls without crashing.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderToast
  swift test
  ```
- **Note**: provider package; tests cover the DTO value semantics and convenience method. Real toast rendering is supplied by the host app.
