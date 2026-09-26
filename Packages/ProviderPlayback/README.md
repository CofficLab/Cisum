# ProviderPlayback

Defines the playback service contract (`PlaybackProviding`), the media-view surface (`PlaybackMediaProviding`), all value types (`PlaybackStatus`, `PlaybackFailure`, `PlaybackMode`, `PlaybackSnapshot`, navigation types), and a reusable `PlaybackObserverStore` event emitter. The concrete player engine lives elsewhere.

## Functional Logic

- **Core responsibility**: abstract playback state, transport controls, seeking, play-mode cycling, and like toggling so cover/control plugins depend on a stable contract rather than a concrete player.
- **Key types**:
  - `PlaybackStatus` (Equatable/Sendable): `.idle`, `.loading(LoadingStatus)`, `.willPlay`, `.playing`, `.paused`, `.stopped`, `.failed(PlaybackFailure)`. `LoadingStatus` = `.connecting` / `.preparing` / `.buffering` / `.downloading(Double)`. Convenience flags: `isPlaying`, `isLoading`, `isDownloading`.
  - `PlaybackFailure`: `.noAsset`, `.invalidAsset`, `.networkError(String)`, `.playbackError(String)`, `.unsupportedFormat(String)`, `.invalidURL(String)`.
  - `PlaybackMode`: `.sequence`, `.loop`, `.shuffle`, `.repeatAll`.
  - `PlaybackSnapshot`: a consistent Sendable snapshot (`state`, `currentURL`, `currentTime`, `duration`, `progress`, `playMode`, `likedAssets`) with `isPlaying`/`hasAsset` helpers; the protocol provides a default `snapshot` computed from stored properties.
  - `PlaybackNavigationDirection` / `PlaybackNavigationFailure`: describe previous/next failures.
  - `PlaybackMediaProviding`: `makeMediaView() -> AnyView`, `localizedStateText(for:)` — used by cover/hero plugins.
  - `PlaybackProviding` (`@MainActor`, `AnyObject`):
    - State: `state`, `currentURL`, `currentTime`, `duration`, `progress`, `playMode`, `likedAssets`, `isPlaying`, `hasAsset`, `snapshot`.
    - Actions: `play(_:)` / `play(_:startTime:)`, `pause()`, `toggle()`, `seek(toProgress:)` / `seek(toTime:)`, `next()`, `previous()`, `setPlayMode(_:)`, `toggleCurrentLike()`, `reset()`, `togglePlayMode()`.
    - Observation: `addObserver(_:)` returns `PlaybackProvidingObserverHandle`.
  - `PlaybackObserverStore<Event>`: generic main-actor event emitter; snapshots callbacks before dispatch so an observer cancelling itself doesn't skip siblings; `PlaybackObserverStoreHandle` weakly references the store and is idempotent on cancel.
- **Events** (`PlaybackProvidingEvent`): `.snapshotChanged`, `.stateChanged`, `.assetChanged`, `.timeChanged`, `.durationChanged`, `.playModeChanged`, `.likedAssetsChanged`, `.likeStatusChanged`, `.previousRequested`, `.nextRequested`, `.navigationFailed`.
- **Dependencies**: none (Foundation/SwiftUI only).

## Testing Logic

- **Test file**: `Tests/ProviderPlaybackTests.swift`.
- **Key scenarios tested**:
  - `PlaybackObserverStore` delivers to active observers, stops after cancel, and lets an observer cancel itself without starving other observers.
  - `PlaybackSnapshot` flags (`isPlaying`, `hasAsset`) and `PlaybackStatus` flags (`isLoading`/`isDownloading`/`isPlaying`) across cases.
  - `NoopPlaybackProvidingObserverHandle` is the default return and is repeatably cancellable.
  - `PlaybackNavigationFailure` preserves direction/reason; `PlaybackMode.allCases` order is stable.
  - Protocol defaults build `snapshot` from stored properties, forward timed `play(_:startTime:)` to `play(_:)`, and `reset()` is a no-op.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderPlayback
  swift test
  ```
- **Note**: provider package; tests cover the value types, observer store, and protocol default methods. Real playback is bridged by the engine plugin.
