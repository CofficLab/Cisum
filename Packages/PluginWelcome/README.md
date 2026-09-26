# PluginWelcome

The first-launch onboarding plugin. It shows a welcome/guide screen when the user has not yet chosen a media storage location, letting them pick iCloud or local storage.

## Functional Logic

- **Core responsibility:** Present the welcome flow only when no storage location is configured, bridge the selection UI to the kernel `StorageProviding` service, and apply the default selection when the guide is completed.
- **Key types:**
  - `WelcomePlugin` — `@MainActor final class` conforming to `AsyncSuperPlugin, SuperLog`. `id = "WelcomePlugin"`, `order = -100`, icon `"hand.wave"`, category `.feature`, policy `.disabled`.
  - `WelcomePluginInfo` — enum with `title = "Welcome"`, `description = "Welcome screen"`, `iconName = "hand.wave"`, `emoji = "👏"`, `order = -100`.
  - `WelcomePluginHost` — static handler registry (`@Sendable` closures) that decouples the welcome views from the kernel. `configure(...)` wires `hasStorageLocation`, `isICloudAvailable`, `currentStorageSelection`, and `updateStorageSelection`.
  - `WelcomeStorageSelection` — public enum `icloud`/`local`.
  - `WelcomeStorageSelectionPolicy` — pure decision helpers: `validatedSelection`, `displayedSelection`, `defaultSelection`, and the on-appear/on-disappear persistence rules.
  - `WelcomeView` — public welcome screen (headline + `StorageView`).
  - `StorageView` — public storage-selection card (iCloud recommended, local fallback; disables iCloud when unavailable).
  - `WelcomePluginGuideView` — wraps `WelcomeView` using `WelcomePluginHost` handlers.
  - Views: `WelcomePluginAboutView`, `WelcomePluginManualView`.
- **Plugin registration:** Registers as `WelcomePlugin`. `onRegister` contributes About/Manual docs. `onBootAsync` contributes the guide view only when `WelcomePluginHost.hasStorageLocation == false`. `onReadyAsync` (after storage is available) wires `WelcomePluginHost` to the kernel's `StorageProviding`. `completeGuidePage()` applies the default selection when the user finishes the guide.
- **Workflow/data flow:**
  1. On first launch (no storage location), the guide view is shown.
  2. `StorageView` lets the user pick iCloud (recommended) or local; iCloud is disabled when unavailable.
  3. On complete, `WelcomeStorageSelectionPolicy.defaultSelection` picks iCloud when available, else local, and persists it via `StorageProviding.setStorageLocation`.
- **Dependencies:** `CisumUIComponents`, `CisumKernelSupport`, `ProviderDocsView`, `ProviderStorage`. Platforms: macOS 14+, iOS 17+. Resources: `Resources/Localizable.xcstrings`.

## Testing Logic

- **Test files:**
  - `Tests/WelcomePluginTests.swift`.
- **Key scenarios tested:**
  - Metadata: `iconName = "hand.wave"`, `emoji = "👏"`, `order = -100`.
  - Selection policy: defaults to iCloud when available; falls back to local when iCloud is unavailable (even if a previous selection was iCloud); displays local as the only option otherwise.
  - Persistence rules: the initial default is not persisted before the user chooses; an existing unavailable iCloud selection is persisted as local; on-disappear persistence follows the same rule.
  - `completeGuidePage()` persists the displayed default selection (iCloud when available, local otherwise) and skips updates when storage already exists.
  - `addGuideView()` returns a view only when no storage location exists; `WelcomePluginHost` forwards updates and exposes availability flags.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginWelcome
  swift test
  ```
- Tests thoroughly cover the pure selection/policy logic and the host bridge (via injected closures); no real storage is touched.
