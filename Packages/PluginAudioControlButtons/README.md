# PluginAudioControlButtons

Playback control buttons plugin for Cisum. It injects the bottom control button group (More / Previous / Play-Pause / Next / Play Mode) into the music playback control area, wired to the playback and navigation providers.

## Functional Logic

- **Core responsibility**: Render and drive the player's bottom control bar. It exposes a `ControlButtonsView` contribution that is only active in the music scene, and translates button taps into playback commands (`toggle`, next/previous navigation, play-mode toggle) with toast/error feedback.
- **Key types / protocols**:
  - `AudioControlButtonsPlugin` — plugin entry (`SuperPlugin`), `id = "AudioControlButtonsPlugin"`, `order = 20`, `iconName = "playpause.fill"`, `policy = .alwaysOn`.
  - `ControlButtonsView` — the SwiftUI button group injected into the control area.
  - `ControlButtonsViewModel` — holds `isPlaying`, `playMode`, `shouldActivateControl`, and issues navigation/playback requests.
  - `ControlButtonsObserver` — subscribes to scene and playback events and pushes state into the view model.
  - `PlaybackCapability` / `PlaybackCapabilityAdapter` — narrows `PlaybackProviding` to the surface the buttons need.
  - `NavigationCapability` / `NavigationCapabilityAdapter` — wraps `AudioTrackNavigationProviding` (next/previous/first/last URL).
  - `ControlButtonsPlaybackRequestPolicy` — generation-based policy that decides whether a late navigation result still applies to the current asset.
  - `PluginControlButtonsAboutView` / `PluginControlButtonsManualView` — docs entries.
- **Plugin registration**: Registers with ID `AudioControlButtonsPlugin`. `onBootAsync` contributes `addControlButtonsView()` to `PluginContributionProviding`. `onReadyAsync` resolves `PlaybackProviding` and `SceneProviding` (throwing `serviceNotAvailable` if missing), plus optional `AudioTrackNavigationProviding` and `ToastProviding`, then builds the view model and observer. The view's "more" button toggles the content view via `RootViewProviding`.
- **Workflow / data flow**:
  1. At boot the control-buttons view is contributed; at ready, capabilities are assembled and the observer starts listening.
  2. The view model reflects playback state (playing/paused, current play mode) and only activates when the current scene is `.music`.
  3. Next/Previous resolve a URL through the navigation capability, then ask playback to play it. At list boundaries without repeat-all, the user is shown an error toast instead of silently failing; with repeat-all, navigation wraps to first/last.
  4. Scene changes bump a generation so in-flight navigation results are discarded; deletion of the currently-playing asset resets playback, while deletion of an unrelated asset is ignored. Failures are de-duplicated per failure identity.
- **Dependencies** (from `Package.swift`): `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `MagicPlayMan`, `ProviderPlayback`, `ProviderAudioNavigation`, `ProviderScene`, `ProviderDocsView`, `ProviderRootView`, `ProviderToast`.

## Testing Logic

- **Test files**: `Tests/ControlButtonsTests.swift`.
- **Key scenarios tested**:
  - `ControlButtonsPlaybackRequestPolicy`: navigation results only apply to the requested current asset; deletion matches the current asset but not another; deactivation invalidates pending requests via generation bump.
  - `ControlButtonsViewModel` integration (using probe stubs for playback, navigation, and toast): init reflects playback state; scene mismatch deactivates the control; playing state tracks asset changes; failure toasts are de-duplicated for identical failures but re-fire for new ones; scene change invalidates pending navigation; Next navigates and plays; Next at end / Previous at start without repeat-all present an error; Next with repeat-all wraps to first; missing capability reports unavailable; deletion of the current asset resets playback while deletion of an unrelated asset is ignored.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioControlButtons
  swift test
  ```
