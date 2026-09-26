# PluginOpenButton

A feature plugin that contributes a "Show in Finder" toolbar button, opening the folder containing the currently playing local file.

## Functional Logic

- **Core responsibility:** Display a toolbar button (macOS) that reveals the current track's file in Finder. The button is only shown when the current asset is a reachable local file.
- **Key types:**
  - `OpenButtonPlugin` — `@MainActor final class` conforming to `AsyncSuperPlugin, SuperLog`. `id = "OpenButtonPlugin"`, `order = 9999`, category `.feature`, policy `.alwaysOn`.
  - `OpenButtonPluginInfo` — enum with `description`, `iconName = .cisumIconFinder`, `toolbarItemId = "open-current"`.
  - `OpenButtonPlaybackCapability` — internal protocol narrowing `PlaybackProviding` to `currentURL`; `OpenButtonPlaybackCapabilityAdapter` adapts the kernel provider.
  - `OpenButtonViewModel` — `ObservableObject` publishing `url`; updates on `assetChanged`.
  - `OpenButtonObserver` — subscribes to `assetChanged` events and forwards them to the view model.
  - `OpenCurrentButtonView` — public SwiftUI button; `shouldShowOpenButton(for:fileExists:)` returns true only for a local file URL that exists on disk; tapping calls `url.openInFinder()`.
  - Views: `OpenButtonPluginAboutView`, `OpenButtonPluginManualView`.
- **Plugin registration:** Registers as `OpenButtonPlugin`. `onBootAsync` contributes the toolbar button (macOS-only) via `PluginContributionProviding`. The view model/observer are assembled lazily in `onReadyAsync` (and re-assembled on `onEnable`), resolving `PlaybackProviding` from the kernel. `onDisable` tears the observer down; `onShutdownAsync` removes the contribution.
- **Workflow/data flow:**
  1. Playback `assetChanged` events update `OpenButtonViewModel.url`.
  2. `OpenCurrentButtonView` shows the button only when `shouldShowOpenButton(for:)` is true (local file that exists).
  3. Tapping opens the file's parent folder in Finder.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `ProviderDocsView`, `MagicPlayMan`, `ProviderPlayback`. Platforms: macOS 14+, iOS 17+. Resources: `Resources/Localizable.xcstrings`.

## Testing Logic

- **Test files:**
  - `Tests/OpenButtonPluginTests.swift` — metadata and the `shouldShowOpenButton` reachability rule.
  - `Tests/OpenButtonCoverageTests.swift` — a `PlaybackProbe`-driven suite for the view model, adapter, and observer.
- **Key scenarios tested:**
  - Metadata stability (`toolbarItemId = "open-current"`, accessibility title `"Show in Finder"`).
  - `shouldShowOpenButton(for:)` accepts an existing local file, rejects a missing local file, and rejects a remote (https) URL.
  - ViewModel reflects the current URL, handles `assetChanged(nil)`, and falls back to `nil` without a capability.
  - The adapter exposes `currentURL`; the observer forwards asset changes and stops after `cancel()`.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginOpenButton
  swift test
  ```
- Tests cover the view model/adapter/observer with fakes and the reachability predicate directly; the button's Finder action itself is not executed.
