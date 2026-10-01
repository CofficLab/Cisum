# ProviderDevice

Defines the `DeviceProviding` protocol: current platform and screen-size information for UI adaptation.

## Functional Logic

- **Core responsibility**: expose whether the app is running on macOS / iOS / iPad, the device model and system version strings, and the available screen dimensions, so views can adapt without querying `UIDevice`/`NSApp` directly.
- **Key protocol**: `DeviceProviding` (`@MainActor`, `AnyObject`, `ObservableObject`):
  - Properties: `isMac: Bool`, `isIOS: Bool`, `isPad: Bool`, `deviceModel: String`, `systemVersion: String`, `screenWidth: CGFloat`, `screenHeight: CGFloat`.
  - Observation: `addObserver(_:)` returns `DeviceProvidingObserverHandle`.
- **Events** (`DeviceProvidingEvent`): `.deviceChanged`.
- **Provider pattern**: consumers call `kernel.resolveProvider((any DeviceProviding).self)`. The default `addObserver` returns `NoopDeviceProvidingObserverHandle`; `cancel()` is idempotent.
- **Dependencies**: none beyond Foundation/SwiftUI.

## Testing Logic

- **Test file**: `Tests/DeviceProvidingTests.swift`.
- **Key scenarios tested**:
  - A stub conforms to `DeviceProviding`; default `addObserver` returns a `NoopDeviceProvidingObserverHandle` without invoking callbacks.
  - `NoopDeviceProvidingObserverHandle.cancel()` is repeatable.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderDevice
  swift test
  ```
- **Note**: provider package; tests verify protocol conformance and the no-op observer fallback.
