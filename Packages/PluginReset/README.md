# PluginReset

A system settings plugin that contributes the "System" settings entry, showing app version and a "Reset Storage Location" flow that clears the user's media storage selection (with a confirmation sheet).

## Functional Logic

- **Core responsibility:** Provide the System settings page and a guarded reset action that calls `StorageProviding.resetStorageLocation()` so the onboarding/storage-selection flow can run again. It does not delete playback, theme, or library records.
- **Key types:**
  - `SystemPlugin` — `@MainActor final class` conforming to `AsyncSuperPlugin, SuperLog`. `id = "SystemPlugin"`, `order = 90`, category `.system`, policy `.disabled`.
  - `ResetPluginInfo` — enum with `title = "System"`, `description = "System settings"`, `iconName = "gearshape"`, `emoji = "⚙️"`, `order = 90`.
  - `SystemSetting` — public SwiftUI settings view showing the current app version and a reset button that presents `ResetConfirm`. `ResetSettingsAction` is the `@Sendable () async -> Void` typealias for the reset closure.
  - `ResetConfirm` — public confirmation sheet describing that the storage selection will be cleared, that preferences are kept, and that the action is irreversible; it disables interactive dismissal while resetting.
  - Views: `SystemPluginAboutView`, `SystemPluginManualView`.
- **Plugin registration:** Registers as `SystemPlugin`. `onRegister` contributes About/Manual docs. `onBootAsync` contributes the "system" settings navigation item (`id: "system"`, icon `gearshape.2`) whose destination calls `StorageProviding.resetStorageLocation()` when the user confirms.
- **Workflow/data flow:**
  1. User opens System settings and taps "Reset Storage Location".
  2. `ResetConfirm` presents a sheet with explanatory rows and a "Continue Reset" button.
  3. On confirm, the sheet shows a loading banner, awaits the reset closure (with a short delay), then dismisses.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `ProviderDocsView`, `ProviderStorage`. Platforms: macOS 14+, iOS 17+. Resources: `Resources/Localizable.xcstrings`.

## Testing Logic

- **Test files:**
  - `Tests/ResetPluginTests.swift`.
- **Key scenarios tested:**
  - `ResetPluginInfo` metadata (`iconName`, `emoji`, `order`).
  - `ResetConfirm.shouldDisableInteractiveDismiss(isResetting:)` is `false` before reset and `true` during reset.
  - Accessibility/label constants: `SystemSetting.resetStorageLocationActionLabel == "Reset Storage Location"` and `ResetConfirm.closeButtonLabel == "Close"`.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginReset
  swift test
  ```
- Tests are light: they verify metadata and pure view-policy helpers. The reset closure itself is not executed.
