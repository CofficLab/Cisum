# PluginAudioControlButtons

Playback control buttons plugin for Cisum. It injects the bottom control button group (More / Previous / Play-Pause / Next / Play Mode) into the music playback control area, wired to the playback and navigation providers.

## Functional Logic

- **Core responsibility**: Render and drive the player's bottom control bar. It exposes a `ControlButtonsView` contribution that is only active in the music scene, and translates button taps into playback commands (`toggle`, next/previous navigation, play-mode toggle) with toast/error feedback.
- **Key types / protocols**:
  - `AudioControlButtonsPlugin` — plugin entry (`SuperPlugin`), `id = "AudioControlButtonsPlugin"`, `order = 20`, `iconName = "playpause.fill"`, `policy = .alwaysOn`.
  - `ControlButtonsView` — the SwiftUI button group injected into the control area.
  - `MoreButtonGuidanceView` — the "more" button plus the empty-repository callout shown above it.
  - `ControlButtonsViewModel` — holds `isPlaying`, `playMode`, `shouldActivateControl`, `isRepositoryEmpty`, and issues navigation/playback requests.
  - `ControlButtonsObserver` — subscribes to scene and playback events and pushes state into the view model.
  - `RepositoryStateObserver` / `RepositoryStateCapabilityAdapter` — turns `AudioLibraryProviding` events into a single "is the repository empty" verdict.
  - `ContentVisibilityObserver` / `ContentVisibilityCapabilityAdapter` — turns `AppStateProviding` visibility events into "is the repository view already open".
  - Uses `PlaybackProviding` and `AudioTrackNavigationProviding` directly.
  - `ControlButtonsPlaybackRequestPolicy` — generation-based policy that decides whether a late navigation result still applies to the current asset.
  - `PluginControlButtonsAboutView` / `PluginControlButtonsManualView` — docs entries.
- **Plugin registration**: Registers with ID `AudioControlButtonsPlugin`. `onBootAsync` contributes `addControlButtonsView()` to `PluginContributionProviding`. `onReadyAsync` resolves `PlaybackProviding` and `SceneProviding` (throwing the shared kernel's typed `providerNotFound` error if missing), plus optional `AudioTrackNavigationProviding` and `ToastProviding`, then builds the view model and observer. The view's "more" button toggles the content view via `ContentViewVisibilityProviding` (resolved from the kernel), so the collapse/expand choice is persisted and stays consistent across launches.
- **Workflow / data flow**:
  1. At boot the control-buttons view is contributed; at ready, Providers are resolved and the observer starts listening.
  2. The view model reflects playback state (playing/paused, current play mode) and only activates when the current scene is `.music`.
  3. Next/Previous resolve a URL through `AudioTrackNavigationProviding`, then ask `PlaybackProviding` to play it. At list boundaries without repeat-all, the user is shown an error toast instead of silently failing; with repeat-all, navigation wraps to first/last.
  4. Scene changes bump a generation so in-flight navigation results are discarded; deletion of the currently-playing asset resets playback, while deletion of an unrelated asset is ignored. Failures are de-duplicated per failure identity.
  5. Empty-repository guidance: the "is the repository empty" verdict comes from the data layer (`AudioLibraryProviding.isRepositoryEmpty`), which only answers after a scan has confirmed the repository holds no audio — an unscanned repository also counts zero files, and that is "not known yet", not "empty". While the repository is empty and its view is still closed, the "more" button carries a callout that points at itself and tells the user to add music; the button keeps toggling the repository view. The brand block at the top of the player is a separate plugin's job (`PluginRepositoryGuide`).
- **Dependencies** (from `Package.swift`): `MagicKit`, `CisumUIComponents`, `KernelCore (LumiKernel), ProviderPlugin, KitAppEvents`, `ProviderPlayback`, `ProviderAudioNavigation`, `ProviderScene`, `ProviderAppState`, `ProviderDocsView`, `ProviderToast`.

## Testing Logic

- **Test files**: `Tests/ControlButtonsTests.swift`, `Tests/RepositoryGuidanceTests.swift`.
- **Key scenarios tested**:
  - `ControlButtonsPlaybackRequestPolicy`: navigation results only apply to the requested current asset; deletion matches the current asset but not another; deactivation invalidates pending requests via generation bump.
  - `ControlButtonsViewModel` integration (using Provider-conforming probes for playback, navigation, and toast): init reflects playback state; scene mismatch deactivates the control; playing state tracks asset changes; failure toasts are de-duplicated for identical failures but re-fire for new ones; scene change invalidates pending navigation; Next navigates and plays; Next at end / Previous at start without repeat-all present an error; Next with repeat-all wraps to first; missing Providers report unavailable; deletion of the current asset resets playback while deletion of an unrelated asset is ignored.
  - `RepositoryStateCapability`: the authoritative empty signal marks the repository empty; post-scan counts decide empty vs. filled; a repository-availability change drops the stale verdict; sorting events change nothing; a cancelled observer stops receiving events; a missing Provider degrades without crashing.
  - `ContentVisibilityCapability`: the visibility verdict follows the event payload (the root view is written *after* the broadcast, so reading it back would lag one toggle); a missing `AppStateProviding` degrades gracefully.
  - `RepositoryGuidance` view model: the callout shows only when the repository is empty *and* its view is closed, and hides again as soon as either condition breaks.
  - `MoreButtonGuidanceView` rendering: the callout adds content above the button, and the area above the button stays blank when the guidance is off.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioControlButtons
  swift test
  ```
