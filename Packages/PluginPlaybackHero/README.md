# PluginPlaybackHero

A feature plugin that injects the now-playing cover/title view into the player control area, including a wide-window right-album art view and a download-progress overlay.

## Functional Logic

- **Core responsibility:** Render the media artwork (provided by the playback engine) and the current track title in the player control bar, adapting to window size and showing a circular progress overlay while a download is in flight.
- **Key types:**
  - `PlaybackHeroPlugin` — `@MainActor final class` conforming to `AsyncSuperPlugin, SuperLog`. `id = "PlaybackHeroPlugin"`, `order = 19`, icon `"photo"`, category `.feature`, policy `.alwaysOn`.
  - `PlaybackHeroPlaybackCapability` — internal protocol narrowing playback to `currentURL`, `state`, `makeHeroView()`, and `localizedStateText(for:)`; `PlaybackHeroPlaybackCapabilityAdapter` combines `PlaybackProviding` with optional `PlaybackMediaProviding` (with `EmptyView`/`String(describing:)` fallbacks).
  - `PlaybackHeroViewModel` — `ObservableObject` publishing `currentURL` and `state`; forwards asset/state changes and delegates media view/state text to the capability.
  - `PlaybackHeroObserver` — subscribes to `assetChanged` and `stateChanged` events.
  - `PlaybackHeroView` — main control-area cover/title view; shows artwork only when the right album pane is hidden and height permits, renders a download-progress ring when state is `.loading(.downloading)`, and shows a demo art image in demo mode.
  - `PlaybackHeroRightAlbumView` — square media art view for the wide-window right album area.
  - Views: `PluginPlaybackHeroAboutView`, `PluginPlaybackHeroManualView`.
- **Plugin registration:** Registers as `PlaybackHeroPlugin`. `onBootAsync` contributes both the hero view and the right album view via `PluginContributionProviding` (`addHeroView` / `addRightAlbumView`). State is assembled in `onReadyAsync`, resolving `PlaybackProviding` and `PlaybackMediaProviding` from the kernel. `onShutdownAsync` removes contributions and cancels the observer.
- **Workflow/data flow:**
  1. Playback `assetChanged`/`stateChanged` events update `PlaybackHeroViewModel`.
  2. The view renders the title (derived from the file name) and either the engine-provided media view, a download progress ring, or the demo image.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `ProviderPlayback`, `ProviderDocsView`. Platforms: macOS 14+, iOS 17+. Resources: `Resources`.

## Testing Logic

- **Test files:**
  - `Tests/PlaybackHeroTests.swift` — uses `PlaybackStub` and `MediaStub` to test the capability adapter, view model, observer, and plugin lifecycle.
- **Key scenarios tested:**
  - Adapter maps playback state and delegates `makeHeroView()`/`localizedStateText(for:)` to the media provider, with safe fallbacks when media is absent.
  - ViewModel initializes from the capability, tracks asset/state changes, and falls back to `.idle`/`EmptyView` without a capability.
  - Observer forwards asset and state events but ignores time changes, and stops after cancellation.
  - Plugin boot registers About/Manual docs, produces both hero and right-album views, and tears them down on shutdown.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginPlaybackHero
  swift test
  ```
- Tests cover the adapter/view-model/observer wiring and plugin assembly with fakes; SwiftUI layout behavior is not asserted.
