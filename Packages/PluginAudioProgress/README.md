# PluginAudioProgress

Audio playback progress plugin for Cisum. It displays the progress bar, persists and restores playback position across sessions, and writes now-playing data for widgets.

## Functional Logic

- **Core responsibility**: Own the progress/seek UI and the playback-position persistence policy — deciding when to save current time, when to restore it, how to merge local and cloud state, and when a stored position should be cleared (e.g. the track was deleted or changed).
- **Key types / protocols**:
  - `AudioProgressPlugin` — plugin entry (`AsyncSuperPlugin`, `SuperLog`), `id = "AudioProgressPlugin"`, `order = 0`, `iconName = "waveform"`, `policy = .disabled`.
  - `AudioProgressViewModel` — drives the progress view, holds current/duration, and triggers save/restore.
  - `AudioProgressObserver` — subscribes to scene, playback, library, and storage events.
  - `AudioStateRepo` — persists and restores the current audio URL/time/play mode, merging local and cloud values.
  - `AudioProgressPersistencePolicy` — pure policy for when to persist/restore/clear progress.
  - `AudioProgressHost` — saves now-playing widget data (title, artist, playing state, cover art).
  - `AudioProgressRootView` / `AudioProgressPluginRootView` — UI.
  - `AudioProgressPlaybackCapability` / `Adapter` — narrows `PlaybackProviding`.
- **Plugin registration**: Registers with ID `AudioProgressPlugin`. `onReadyAsync` resolves `SceneProviding` and `PlaybackProviding`, wires the view model with `audioLibrary` (`AudioLibraryProviding`), `audioLike` (`AudioLikeProviding`), and a `saveWidgetData` closure to `AudioProgressHost`, then starts the observer. `addRootView(content:)` contributes the root view.
- **Workflow / data flow**:
  1. Progress is persisted when leaving the audio scene (not while staying in it, to avoid duplicate saves).
  2. The current audio URL stored is the current supported track; unsupported URLs keep the previous stored track; empty cloud URLs are ignored. URL parsing trims whitespace and accepts both `file://` and legacy path strings.
  3. Time resolution prefers a valid local time over stale cloud time; invalid local times fall back to cloud; NaN/infinity/negative times normalize to 0.
  4. Switching to a genuinely different track resets the global restore time (but a symlinked equivalent does not); a deleted or unplayable stored track clears restore state; restore results only apply if the current audio did not change and the scene did not change in the meantime, and an already-loaded asset is not replayed.
- **Dependencies** (from `Package.swift`): `MagicKit`, `CisumUIComponents`, `ProviderAudioLibrary`, `ProviderAudioLike`, `MagicPlayMan`, `CisumKernelSupport`, `ProviderDocsView`, `ProviderScene`, `ProviderPlayback`, `ProviderStorage`. Resources: `Localizable.xcstrings`.

## Testing Logic

- **Test files**: `Tests/AudioProgressPluginTests.swift`.
- **Key scenarios tested**:
  - Metadata: `AudioProgressPluginInfo.titleKey == "Audio Progress"`.
  - Persistence policy: leaving the audio scene persists progress; entering/staying in the scene does not; nil current URL persists nil; supported URLs persist; unsupported URLs keep the previous.
  - `AudioStateRepo.storedURL`: empty/nil ignored, trims whitespace, parses `file://` and legacy path strings, rejects non-URLs.
  - `AudioStateRepo.storedTime`: local zero overrides stale cloud time; invalid local times fall back to cloud; `normalizedTimeForStorage` clamps NaN/infinity/negative to 0.
  - Play-mode resolution falls back to cloud for invalid local modes.
  - Restore reset/clear: a different current URL resets global time (symlinked URL does not; distinct dangling symlink does); deleted/unplayable stored current clears restore state; restore results apply only when the current audio and scene are unchanged; already-loaded audio is not replayed.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioProgress
  swift test
  ```
