# PluginPlaybackHero

A feature plugin that injects the now-playing cover/title view into the player control area, including a wide-window right-album art view and a download-progress overlay.

## Functional Logic

- **Core responsibility:** Render the media artwork (provided by the playback engine) and the current track title in the player control bar, adapting to window size and showing a circular progress overlay while a download is in flight.
- **Key types:**
  - `PlaybackHeroPlugin` — `@MainActor final class` conforming to `AsyncSuperPlugin, SuperLog`. `id = "PlaybackHeroPlugin"`, `order = 19`, icon `"photo"`, category `.feature`, policy `.alwaysOn`.
  - Reads playback state from `PlaybackProviding` and artwork/state presentation from optional `PlaybackMediaProviding` directly; absent media uses an empty view and plain state description.
  - `PlaybackHeroViewModel` — `ObservableObject` publishing playback state plus music-repository emptiness and active-scene state; hides the player Hero only when the Music scene is active and its repository is confirmed empty. Also derives `showsIdlePlaceholder` — the state where the library has tracks but none is selected yet.
  - `PlaybackHeroObserver` — subscribes to playback, `AudioLibraryProviding`, and `SceneProviding` events; an empty music repository does not hide the title while the Audiobooks scene is active. Seeds the initial repository conclusion (event streams only report *changes*, so a library that was already scanned would otherwise never be noticed) and publishes Hero visibility for both the real cover and the idle placeholder.
  - `PlaybackHeroView` — main control-area cover/title view; shows artwork only when the right album pane is hidden and height permits, renders a download-progress ring when state is `.loading(.downloading)` (the ring's centre shows the percentage, the small caption below it shows only the plain "正在下载" label), and shows a demo art image in demo mode. In the idle-placeholder state it renders the brand artwork plus a localized "Pick a track to start playing" caption in place of the track title.
  - `PlaybackHeroRightAlbumView` — square media art view for the wide-window right album area; falls back to the brand artwork in the idle-placeholder state so the wide layout never shows an empty column.
  - Views: `PluginPlaybackHeroAboutView`, `PluginPlaybackHeroManualView`.
- **Plugin registration:** Registers as `PlaybackHeroPlugin`. `onReadyAsync` contributes both the hero view and the right album view via `PluginContributionProviding` (`addHeroView` / `addRightAlbumView`), resolving `PlaybackProviding`, `PlaybackMediaProviding`, `AudioLibraryProviding`, and `SceneProviding` from the kernel. `onShutdownAsync` removes contributions and cancels all observers.
- **Workflow/data flow:**
  1. Playback `assetChanged`/`stateChanged` events update `PlaybackHeroViewModel`; confirmed empty-library events hide the Hero, while a non-empty sync/update restores it.
  2. `ControlHeroVisibility.shared` carries Hero visibility to `ProviderControlView` and `ProviderRootView`; it stays `true` for the idle placeholder too, so the control area keeps its height and the placeholder actually has room to render.
  3. The view renders the title (derived from the file name) and either the engine-provided media view, a download progress ring, or the demo image.
- **Idle placeholder (no current track):** The library can be non-empty while nothing is selected — on a fresh launch there is no `current-playback.plist` entry, so no current track exists. Neither the real cover (it needs a current URL) nor the empty-repository guide (it needs an empty library) covers that area, leaving the top of the control bar blank. The placeholder takes over: brand artwork plus a short caption, in the same visual language as the guide. It requires a **confirmed non-empty** library — the data layer's scan state is three-valued (unknown / empty / non-empty), and showing the placeholder before the scan concludes would make it flash on every launch.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `KernelCore (LumiKernel), ProviderPlugin, KitAppEvents`, `ProviderPlayback`, `ProviderAudioLibrary`, `ProviderScene`, `ProviderDocsView`. Platforms: macOS 14+, iOS 17+. Resources: `Resources`.

## Testing Logic

- **Test files:**
  - `Tests/PlaybackHeroTests.swift` — uses `PlaybackStub` and `MediaStub` to test direct Provider use, view model, observer, and plugin lifecycle.
- **Key scenarios tested:**
  - ViewModel initializes from Provider state, tracks asset/state changes, and falls back to `.idle`/`EmptyView` when Providers are absent.
  - Observer forwards asset and state events but ignores time changes, and stops after cancellation.
  - Confirmed empty-library events hide the Hero only in the Music scene; positive-count library events restore it, and cancellation stops updates.
  - **Idle placeholder**: shows when the library is confirmed non-empty and no track is selected; stays hidden while the scan conclusion is unknown; stays hidden for an empty library (the guide owns that area); yields to the real cover once a track is selected; stays hidden outside the Music scene.
  - Plugin boot registers About/Manual docs, produces both hero and right-album views, and tears them down on shutdown.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginPlaybackHero
  swift test
  ```
- Tests cover direct Provider/view-model/observer wiring and plugin assembly with fakes; SwiftUI layout behavior is not asserted.
