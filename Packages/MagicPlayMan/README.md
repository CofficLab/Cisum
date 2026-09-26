# MagicPlayMan

A universal AVFoundation-backed media playback engine for Cisum, supporting local and network audio/video (MP3, WAV, MP4, HLS) with play modes, like/favorite tracking, download-and-cache, system remote control, Now Playing info, and a full set of self-observing SwiftUI control views.

## Functional Logic

- **Core responsibility**: Own a single `AVPlayer`, drive it from SwiftUI `@Published` state, and expose both a Combine/notification event surface and ready-made SwiftUI views. It validates URLs, handles iCloud dataless downloads, caches remote assets to disk, normalizes time/progress math, and forwards next/previous requests to an external queue (the engine itself does not own a playlist).

- **Key types** (under `Sources/`):
  - `MagicPlayMan` (`Man.swift`) — the `@MainActor ObservableObject` core. Holds the internal `AVPlayer` (`_player`), a periodic time observer, `MPNowPlayingInfoCenter` state, an `AssetCache`, `PlaybackEvents`, and `@Published` `playMode`, `currentURL`, `state`, `currentTime`, `duration`, `progress`, `likedAssets`. Also defines `MagicPlayManPlaybackTimePolicy` (finite/clamp normalization) and internal setters (`setState`, `setCurrentTime`, `setDuration`, `setProgress`, `setCurrentURL`, `setPlayMode`) plus a play-request generation counter (`beginPlayRequest` / `isCurrentPlayRequest`) to invalidate stale async loads.
  - `PlaybackEvents` (`Man+Subscription.swift`) — `ObservableObject` holding `PassthroughSubject`s: `onStateChanged`, `onPlaybackFailed`, `onTrackFinished`, `onPreviousRequested`, `onNextRequested`, `onNavigationFailed`, `onLikeStatusChanged`, `onPlayModeChanged`, `onCurrentURLChanged`, `onBufferingStateChanged`. External callers `subscribe(name:...)` with optional callbacks and receive a `UUID` to `unsubscribe`. `addNavigationSubscriber` marks a subscriber as a queue owner (required before `next()`/`previous()` will emit).
  - `PlaybackState` (`Models/PlaybackState.swift`) — an `Equatable` enum: `.idle`, `.loading(LoadingState)`, `.willPlay`, `.playing`, `.paused`, `.stopped`, `.failed(PlaybackError)`. `LoadingState` is `.connecting`/`.preparing`/`.buffering`/`.downloading(Double)`. `PlaybackError` covers `.noAsset`, `.invalidAsset`, `.networkError`, `.playbackError`, `.unsupportedFormat`, `.invalidURL`, with localized descriptions and recovery suggestions. Includes `StateView`.
  - `MagicPlayMode` (`Models/MagicPlayMode.swift`) — `.sequence`, `.loop`, `.shuffle`, `.repeatAll`, with `displayName`, `shortName`, `iconName`, `next` cycling, `toastMessage`, and SwiftUI helpers (`button`, `indicator`, `label`). Also ships `PlayModeIndicator` and `PlayModeButton`.
  - `MagicAsset` (`Models/MagicAsset.swift`) — `Identifiable, Equatable` value type wrapping a `URL` and `Metadata` (title, artist, album, artwork, duration). Equality is by identity (`id`).
  - `AssetCache` (`Models/AssetCache.swift`) — SHA-256-keyed on-disk cache: `isCached`, `cachedURL`, `cache(_:for:)`, `clear`, `size()`, `validateCache(for:)`, `removeCached`. `AssetCacheFileSizePolicy` normalizes file-size attributes.
  - `SupportedFormat` (`Models/SupportedFormat.swift`) — declares MP3, WAV, MP4, and HLS formats with bundled sample URLs (NASA audio, Chinese traditional music, Blender open movies, Apple HLS streams).
  - `Localization` (`Models/Localization.swift`) — string-catalog-backed localization with a fallback that reads the raw `.xcstrings` JSON directly (used under `swift test`), plus a SwiftUI environment entry.
  - Policy enums (file-private/internal): `MagicPlayManPlaybackRequestPolicy` (URL validation), `MagicPlayManSeekPolicy`, `MagicPlayManControlInputPolicy` (volume/skip clamping), `MagicPlayManDownloadRequestPolicy` / `MagicPlayManDownloadObserverPolicy` / `MagicPlayManAssetIdentity` (symlink-aware asset identity), `MagicPlayManTimeUpdatePolicy`.
  - Notification events (`Events/`) — each file posts a `Notification.Name` (`.playManStateChanged`, `.playManTimeUpdate`, `.playManAssetChanged`, `.playManBufferingStateChanged`, `.playManDownloadProgressChanged`, `.playManDurationChanged`) and adds `NotificationCenter.observe…` and SwiftUI `.onPlayMan…` helpers.
  - Setup extensions: `Man+Initialize.swift` (convenience init, `setupPlayer` periodic observer, `setupObservers` reacting to `AVPlayer.status`/`timeControlStatus`/buffer/duration/end/failure), `Man+Controls.swift` (`play`, `pause`, `playCurrent`, `toggle`, `seek`, `skipBackward/Forward`, `setVolume`, `setMuted`, `setLike`/`toggleLike`, `stop`, `reset`, `next`/`previous`), `Man+Load.swift` (download-and-cache with throttled progress and stale-request cancellation), `Man+Remote.swift` (MPRemoteCommandCenter targets + Now Playing metadata/artwork), `Man+Buttons.swift` (self-observing button factories), `Man+Views.swift` (`makeMediaView`, `makeHeroView`, `makeProgressView`, `makeStateView`, `getPreviewView`), `Man+Get.swift` (accessors), `Man+PlayMode.swift`, `Man+Samples.swift`.
  - View layer: `View/` (button overlays: `PlayPauseButtonView`, `PreviousButtonView`, `NextButtonView`, `RewindButtonView`, `ForwardButtonView`, `LikeButtonView`, `PlayModeButtonView`, `MagicProgressView`, `HeroView`, `LoadingOverlay`, `ErrorOverlay`, `MediaPickerButton`, `SubscribersView`), `ViewAudio/` (`AudioPlayerView`, `AudioContentView`), `ViewVideo/` (`VideoPlayerView`, `VideoView`), `ViewPreview/` (`PreviewView` and its content/controls/overlay/toolbar/helpers extensions).

- **Workflow/data flow**:
  1. Caller creates `MagicPlayMan(cacheDirectory:locale:defaultArtwork:)`, which builds the `AssetCache`, installs a 0.5s periodic time observer, subscribes to AVPlayer status/buffer/duration/end/failure publishers, and registers MPRemoteCommandCenter targets.
  2. To play: `man.play(_:autoPlay:startTime:reason:)` bumps a request generation, validates the URL, waits for iCloud/local availability if needed, checks `isPlayable`, resets time/progress, and (for file URLs) runs `downloadAndCache` before replacing the player item. Any async result checks `isCurrentPlayRequest` and `representsSameAsset` before applying — stale loads are discarded.
  3. AVPlayer callbacks update `@Published` state and post both Combine events and `NotificationCenter` notifications; the system Now Playing center is updated with title, duration, elapsed time, rate, and artwork.
  4. On track end, `.loop` mode restarts immediately; otherwise the engine posts `onNextRequested` for the external queue to handle. `next()`/`previous()` only fire if a navigation subscriber is registered.
  5. SwiftUI views observe the `@Published` state directly (self-observing buttons/progress/hero) or subscribe via `man.subscribe(...)`.

- **Dependencies** (from `Package.swift`): only `CisumUIComponents` (which re-exports MagicKit and LumiUI). Platforms: macOS 14 / iOS 17.

## Testing Logic

- **Test files** (all under `Tests/`):
  - `AssetCacheTests.swift` — `AssetCache` behavior.
  - `DownloadPolicyTests.swift` — download/observer asset-identity policies.
  - `MagicPlayManAsyncTests.swift` — broad async/integration surface of `MagicPlayMan`.
  - `MagicPlayManCoreTests.swift` — core identity/validation policies plus `PolicyTests`.
  - `MagicPlayModePlaybackStateTests.swift` — mode cycling and state/error surface.
  - `PlaybackTimePolicyTests.swift` — numeric normalization and play-mode surface.
- **Key scenarios tested**:
  - **Asset cache**: distinct same-filename URLs get separate cache files; long signed URLs hash to short names; cached size sums; file-size attribute coercion; replacing a file/dangling symlink at the cache root.
  - **Download policies**: stale results ignored when the current asset changes; symlinked file URLs resolve to the same asset; remote URLs require exact identity; observer cleanup only touches matching requests.
  - **Engine lifecycle**: replacing download observers cancels previous ones; `reset`/`stop` clear observers and invalidate pending play requests; NaN/infinity/negative times and durations are clamped; progress is clamped to 0…1; `restorePlayMode` does not notify subscribers; unsubscribe cancels handlers.
  - **Like/asset identity**: liked-set lookups work across symlinks; distinct dangling symlink targets do not collide; adding/removing like replaces the stored symlinked entry.
  - **Playback failures**: unplayable local media leaves `currentURL` set and surfaces `.invalidAsset`; failed playback notifies `onPlaybackFailed`; `AVPlayerItemFailedToPlayToEndTime` resets the item but keeps the selection; stale (non-current-item) failure notifications are ignored.
  - **Navigation & controls**: `next`/`previous`/`seek`/`pause`/`setLike` are safe with no asset; volume clamps to 0…1; mute toggles; toggle behaves correctly in each state; stop synchronizes published state.
  - **Policies**: playback-request validation rejects missing/unsupported files and accepts HLS/audiobooks; seek normalizes out-of-range times; control input normalizes volume/skip; time-update payload normalization.
  - **Models**: `MagicPlayMode` display names/icon/cycling; `PlaybackState` flags (`isPlaying`, `isLoading`, `isDownloading`, `canSeek`), icon/text, download-percent clamping, localized error descriptions/reasons/suggestions, and equality; `MagicAsset` metadata defaults and identity equality.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/MagicPlayMan
  swift test
  ```
