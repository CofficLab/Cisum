# PluginLikeButton

A feature plugin that contributes a heart-shaped like/unlike toggle button to the main window toolbar, reflecting and controlling the like state of the currently playing asset.

## Functional Logic

- **Core responsibility:** Show whether the current track is liked, toggle it on tap, and keep the button in sync with playback events. The button only appears when an asset is loaded.
- **Key types:**
  - `LikeButtonPlugin` — `@MainActor final class` conforming to `AsyncSuperPlugin, SuperLog`. `id = "LikeButtonPlugin"`, `order = 9999`, category `.feature`, policy `.disabled`.
  - `LikeButtonPluginInfo` — enum with `description`, `iconName = "heart"`, `toolbarItemId = "like-toggle"`.
  - `LikeButtonViewModel` — `ObservableObject` publishing `hasAsset` and `isLiked`; uses the shared `PlaybackProviding` contract and handles asset/like events and `toggleLike()`.
  - `LikeButtonObserver` — subscribes to `PlaybackProviding` events (`assetChanged`, `likeStatusChanged`, `likedAssetsChanged`) and forwards them to the view model.
  - `LikeToggleButtonView` — public SwiftUI button showing `heart`/`heart.fill`, red when liked; hides itself when no asset.
  - Views: `LikeButtonPluginAboutView`, `LikeButtonPluginManualView`.
- **Plugin registration:** Registers as `LikeButtonPlugin`. `onBootAsync` contributes the toolbar button via `PluginContributionProviding.addToolBarButtons`. Because the playback provider may not be registered yet at boot, the view model/observer are assembled lazily in `onReadyAsync` (and re-assembled on `onEnable`), resolving `PlaybackProviding` from the kernel. `onDisable` tears the observer down; `onShutdownAsync` removes the contribution and tears down state.
- **Workflow/data flow:**
  1. Kernel playback events flow into `LikeButtonObserver`, which updates `LikeButtonViewModel`.
  2. `LikeToggleButtonView` observes the view model and renders the filled/outline heart.
  3. A tap calls `viewModel.toggleLike()` → `PlaybackProviding.toggleCurrentLike()`.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `KernelCore (LumiKernel), ProviderPlugin, KitAppEvents`, `ProviderDocsView`, `MagicPlayMan`, `ProviderPlayback`. Platforms: macOS 14+, iOS 17+. Resources: `Resources/Localizable.xcstrings`.

## Testing Logic

- **Test files:**
  - `Tests/LikeButtonPluginTests.swift` — uses a `PlaybackProbe` conforming to `PlaybackProviding` to drive the view model and observer without a real player.
- **Key scenarios tested:**
  - Metadata stability (`toolbarItemId`, icon, description).
  - ViewModel initialization from the provider, fallback when playback is unavailable, and reactions to `assetChanged`, `likeStatusChanged`, and `likedAssetsChanged` events.
  - `toggleLike` forwards to `PlaybackProviding.toggleCurrentLike()`.
  - Observer forwards playback events to the view model and stops after `cancel()`.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginLikeButton
  swift test
  ```
- Tests cover the view model/observer in isolation with provider fakes; they do not boot the full plugin lifecycle.
