# ProviderCloud

Defines the `CloudProviding` protocol: iCloud availability and signed-in state, wrapping `MagicApp.isICloudAvailable()` and the system `CKAccountChanged` notification. Corresponds to the legacy `CloudVM` surface.

## Functional Logic

- **Core responsibility**: expose iCloud availability (derived from `FileManager.ubiquityIdentityToken != nil`) and account status to the rest of the app, broadcasting changes when the system account changes.
- **Key protocol**: `CloudProviding` (`@MainActor`, `AnyObject`, `ObservableObject`):
  - Properties: `isICloudAvailable: Bool`, `isSignedIn: Bool?` (nil = undetermined), `accountStatusDescription: String`.
  - Observation: `addObserver(_:)` returns `CloudProvidingObserverHandle`.
- **Events** (`CloudProvidingEvent`): `.availabilityChanged(isICloudAvailable: Bool, isSignedIn: Bool?)`.
- **Provider pattern**: consumers resolve via `kernel.resolveProvider((any CloudProviding).self)`. The default `addObserver` returns `NoopCloudProvidingObserverHandle`; `cancel()` is idempotent.
- **Dependencies**: none (Foundation only).

## Testing Logic

- **Test file**: `Tests/CloudProvidingTests.swift`.
- **Key scenarios tested**:
  - A stub conforms to `CloudProviding`; default `addObserver` returns a `NoopCloudProvidingObserverHandle` without invoking callbacks.
  - `NoopCloudProvidingObserverHandle.cancel()` is repeatable.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderCloud
  swift test
  ```
- **Note**: provider package; tests verify protocol conformance and the no-op observer fallback. Real iCloud state requires a signed-in device.
