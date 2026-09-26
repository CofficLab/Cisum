# FactoryCisum

The Cisum composition root: the single place that knows how to assemble the app — creates the kernel, registers infrastructure providers, instantiates the built-in plugin list, builds the main and settings windows, and wires up app commands.

## Functional Logic

- **Core responsibility**: Bootstrap the entire Cisum app. It owns the kernel lifecycle, the default plugin list, the registration of cross-cutting providers (app state, theme, cloud, device, docs, toast, root/control/content views), and the root view assembly. The host app target only calls into this package; it does not know about individual plugins.

- **Key types** (under `Sources/FactoryCisum/`):
  - `CisumBuilder` (a.k.a. `FactoryCisum`) (`FactoryCisum.swift`) — the main factory enum. Holds a static list of created kernels (`kernels`, `mainKernel`); `createKernel(configuration:pluginFactory:)` builds a `KernelCoreContainer`, registers `BasicAppStateService`, `PluginContributionService`, `ThemeService`, `CloudService`, `DeviceService`, docs/toast providers, and view providers, then calls `kernel.startAsync(plugins:)`. `createMainKernel` is idempotent. `assembleMainView(kernel:)` resolves root/control/content providers and injects hero/right-album/buttons/progress/tab contributions. It also subscribes to plugin-enable and scene-change notifications to rebuild content tabs.
  - `PluginFactory` / `DefaultPluginFactory` / `SelectedPluginFactory` (`PluginFactory.swift`) — protocol for producing the plugin list; the default factory hard-codes Cisum's built-in plugins (audio/book stacks, playback, scene, toast, storage, store, settings, ~15 theme plugins, welcome, etc.), with macOS-only plugins (copy, file log, settings button) gated by `#if os(macOS)`. `SelectedPluginFactory` filters a base factory by an allowed id set.
  - `FactoryCisumConfiguration` (`Bootstrap/FactoryCisumConfiguration.swift`) — an empty `Sendable` struct reserved for future boot-time knobs.
  - `AppBootstrap` (`Bootstrap/AppBootstrap.swift`) — launch constants: app name, window ids (`cisum.main`, `cisum.settings`), default window sizes (reusing `CisumPlayerLayout`).
  - `AppDelegate` / `AppWindowController` (`Bootstrap/AppDelegate.swift`, macOS only) — disables state restoration, enforces the main window minimum size, and re-activates the existing main window on Dock reopen.
  - `CisumAppCommands` (`AppCommands.swift`) — the SwiftUI `Commands` scene; installs the Settings… menu item (⌘,) and, on macOS, runs `CisumMenuInstaller` which synchronizes dynamic top-level DEBUG and Theme menus into the AppKey main menu by polling.
  - `CloudService` (`Services/CloudService.swift`) — `CloudProviding` implementation wrapping `MagicApp.isICloudAvailable()` and observing `CKAccountChanged`.
  - `DeviceService` (`Services/DeviceService.swift`) — `DeviceProviding` implementation exposing `isMac`/`isIOS`/`isPad`, device model/system version, and primary screen size.
  - `WindowMain` (`Views/WindowMain.swift`) — the main window root view: shows `KernelLoadingView` while booting, `KernelErrorView` on failure, then `KernelRootView(kernel:)`.
  - `SettingsWindowHost` (`Views/SettingsWindowHost.swift`) — boots (or reuses) the main kernel and injects `ProviderSettings.SettingsWindow` with a toast overlay.
  - `KernelRootView` (`Views/KernelRootView.swift`) — wraps assembled content in a `NavigationStack`, applies the theme background, and rebuilds when `contributionRevision` bumps on plugin/scene changes.
  - `KernelLoadingView` / `KernelErrorView` (`Views/`) — boot-state placeholders; the error view surfaces the failing plugin id when the error is `.pluginFailed`.
  - `MainWindowMinimumSizeBridge` / `WindowMinimumSizeView` (`Views/MainWindowMinimumSizeBridge.swift`, macOS) — `NSViewRepresentable` that syncs SwiftUI's minimum frame to `NSWindow.contentMinSize`.
  - `SettingsWindowHost`, `WindowMain` — both call `FactoryCisum.createMainKernel(configuration:)`.

- **Workflow/data flow**:
  1. Host app creates `WindowMain(configuration:)` (or `makeMainWindow`).
  2. `.task` calls `FactoryCisum.createMainKernel(configuration:)`.
  3. The factory builds a `KernelCoreContainer`, asks `DefaultPluginFactory` for the plugin list, registers infrastructure providers (app state, contributions, theme, cloud, device, docs, toast, root/control/content views), then `kernel.startAsync(plugins:)` runs plugin `onBoot` → service validation → `onReady` → contribution aggregation.
  4. The factory subscribes to enabled-plugin and scene-change notifications.
  5. `KernelRootView` observes those notifications, bumps `contributionRevision`, and re-runs `assembleMainView(kernel:)` to rebuild the root view with fresh tab/control contributions.

- **Dependencies** (from `Package.swift`): CisumKernelSupport, CisumUIComponents, MagicKit, ~10 Provider contracts (Cloud, ContentView, ControlView, Device, DocsView, RootView, Scene, Settings, Toolbar, Toast), and ~50 Plugin packages (audio/book stacks, themes, playback, settings, utility).

## Testing Logic

- **Test files**:
  - `Tests/FactoryCisumTests.swift` — Swift Testing suite (`@MainActor struct`).
- **Key scenarios tested**:
  - `defaultPluginFactoryProducesUniquePluginIDs` — the default factory produces more than 40 plugins with no duplicate ids.
  - `selectedPluginFactoryPreservesBaseOrderAndFiltersByID` — filtering by an allowed id set preserves base order and drops the rest.
  - `mainViewAssemblyFallsBackWhenRootProviderIsMissing` — `assembleMainView` does not crash on an empty kernel.
  - `mainViewAssemblyInjectsControlAndContentProviders` — after registering root/control/content providers, assembly wires the control and content views and leaves demo mode off / tabs empty.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/FactoryCisum
  swift test
  ```
