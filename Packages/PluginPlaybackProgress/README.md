# PluginPlaybackProgress

A feature plugin that injects the seekable progress bar into the player control area, updating live as playback advances and seeking the engine when the user drags.

## Functional Logic

- **Core responsibility:** Show the current playback position/duration and allow scrubbing. It self-observes playback time changes and forwards seek requests to the playback engine.
- **Key types:**
  - `PlaybackProgressPlugin` — `@MainActor final class` conforming to `AsyncSuperPlugin, SuperLog`. `id = "PlaybackProgressPlugin"`, `order = 21`, icon `"waveform"`, category `.feature`, policy `.alwaysOn`.
  - `PlaybackProgressCapability` — internal protocol narrowing playback to `currentTime`, `duration`, and `seek(toTime:)`; `PlaybackProgressCapabilityAdapter` adapts `PlaybackProviding` (weakly held, with zero fallbacks).
  - `PlaybackProgressViewModel` — `ObservableObject` publishing `currentTime` and `duration`; normalizes seek input (rejects NaN/negative to 0) and re-syncs on asset changes.
  - `PlaybackProgressObserver` — subscribes to `timeChanged`, `durationChanged`, and `assetChanged` events.
  - `PlaybackProgressView` — hosts `MagicProgressBar`, exposing a live `Binding` for the current time and an `onSeek` callback.
  - Views: `PluginPlaybackProgressAboutView`, `PluginPlaybackProgressManualView`.
- **Plugin registration:** Registers as `PlaybackProgressPlugin`. `onBootAsync` contributes the progress view via `PluginContributionProviding.addProgressView`. State is assembled in `onReadyAsync` (and re-assembled on `onEnable`), resolving `PlaybackProviding` from the kernel. `onDisable` tears the observer down; `onShutdownAsync` removes the contribution.
- **Workflow/data flow:**
  1. `timeChanged`/`durationChanged`/`assetChanged` events update the view model.
  2. Dragging the bar updates the displayed time via the binding (without seeking), and releasing calls `onSeek` → capability → `PlaybackProviding.seek(toTime:)`.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `ProviderPlayback`, `ProviderDocsView`. Platforms: macOS 14+, iOS 17+. Resources: `Resources`.

## Testing Logic

- **Test files:**
  - `Tests/PlaybackProgressTests.swift` — uses `PlaybackStub` and `PlaybackCapabilityStub` to test the adapter, view model, binding, observer, and full plugin lifecycle.
- **Key scenarios tested:**
  - Adapter forwards time/duration and seeks; degrades to 0 after the playback stub is released.
  - ViewModel syncs initial/asset state and normalizes seek input (`-1`/`.nan` become 0).
  - The view's time binding updates the display without triggering a seek, while `handleSeek` forwards to the capability.
  - Observer routes time/duration/asset events and stops after cancellation; an observer with no playback can still be cancelled safely.
  - Plugin lifecycle: docs registered exactly once, progress view produced, observer count stays 1 across repeated `onReady`, drops to 0 on `onDisable`, returns to 1 on `onEnable`, and clears on shutdown; missing optional providers are tolerated; about/manual views build.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginPlaybackProgress
  swift test
  ```
- Tests are among the more thorough in this group: they cover seek normalization, binding semantics, observer cancellation, and the enable/disable lifecycle.
