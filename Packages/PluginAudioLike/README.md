# PluginAudioLike

Audio favorites/likes plugin for Cisum. It persists like/unlike state for tracks, registers the `AudioLikeProviding` service, and contributes a "Liked audio" settings entry plus a favorites root view.

## Functional Logic

- **Core responsibility**: Own the local likes store (SwiftData model + repository), expose it as `AudioLikeProviding`, and drive the like UI — toggling the current track's favorite, listing liked tracks, and persisting status.
- **Key types / protocols**:
  - `AudioLikePlugin` — plugin entry (`AsyncSuperPlugin`, `SuperLog`), `id = "AudioLikePlugin"`, `order = 3`, `iconName = "heart"`, `emoji = "❤️"`, `policy = .disabled`.
  - `AudioLikeProvider` — concrete `AudioLikeProviding` implementation (all liked items, update like status).
  - `AudioLikeRepo` / `AudioLikeModel` / `AudioLikeRepositoryConfiguration` / `AudioLikeRepoError` — SwiftData persistence layer.
  - `AudioLikeViewModel` — loads liked audios, gates saving on scene activation, and toggles like status.
  - `AudioLikeObserver` — forwards scene/playback events to the view model.
  - `AudioLikeRootView` / `AudioLikePluginRootView` / `AudioLikeSettingsView` — UI.
  - `AudioLikePlaybackCapability` / `Adapter` — narrows `PlaybackProviding`.
  - `AudioLikeEvents` — notifications; `AudioLikePluginInfo` — metadata.
- **Plugin registration**: Registers with ID `AudioLikePlugin`. `onBootAsync` contributes a settings navigation item (`addSettingNavigationItem`, id `"liked-audio"`; `addSettingView()` returns nil). `onReadyAsync` first installs `AudioLikeProviding` (using `StorageProviding`), then assembles the view model and observer. The view model receives narrow closures (`loadLikedAudios`, `saveLikeStatus`) rather than the kernel or provider directly.
- **Workflow / data flow**:
  1. Likes are stored by audio id with url/title metadata; unliking a track removes the record (no record is created for unliked audio).
  2. Symlinked tracks resolve to the same like record; distinct dangling symlinks are treated separately. Duplicate likes from a symlinked source are replaced.
  3. Toggling like only persists when the music scene is active; leaving the scene gates further saves. Liked list reloads apply only the latest generation (stale loads discarded).
  4. Like-status changes post a notification delivered on the main thread.
- **Dependencies** (from `Package.swift`): `ProviderAudioLike`, `ProviderStorage`, `MagicKit`, `CisumUIComponents`, `MagicPlayMan`, `CisumKernelSupport`, `ProviderDocsView`, `ProviderScene`, `ProviderPlayback`. Resources: `Localizable.xcstrings`.

## Testing Logic

- **Test files**: `Tests/AudioLikePluginTests.swift`.
- **Key scenarios tested**:
  - Metadata: `iconName == "heart"`, `emoji == "❤️"`, `order == 3`; the settings navigation item exposes id `"liked-audio"` and title "Liked audio" (while `addSettingView()` returns nil).
  - Main-thread delivery: like-status notification is delivered on the main thread.
  - `AudioLikeRepo`: unliked audio does not create a stored record; liking then unliking creates then removes the record; the repo honors a reconfigured database URL; persists url/title metadata and backfills missing metadata; matches a symlinked liked audio; does not match distinct dangling symlinks; unlikes a symlinked stored audio; replaces a symlinked duplicate like (single liked entry).
  - `AudioLikeViewModel`: reload applies only the latest generation; scene activation gates like saving (inactive → no save, active → saves and posts, leaving → gates again); observer forwards scene selection without crashing.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioLike
  swift test
  ```
