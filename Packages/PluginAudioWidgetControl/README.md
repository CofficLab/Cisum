# PluginAudioWidgetControl

Widget control plugin for Cisum. It listens for playback commands raised by home-screen / lock-screen widgets (play-pause, next, previous) and translates them into playback and navigation actions.

## Functional Logic

- **Core responsibility**: Consume intents from widget intents (stored in shared `UserDefaults`) — toggling play/pause and navigating to next/previous/first/last track — and execute them against the playback and navigation providers, even when the app UI is not in the foreground.
- **Key types / protocols**:
  - `AudioWidgetControlPlugin` — plugin entry (`AsyncSuperPlugin`, `SuperLog`), `id = "AudioWidgetControlPlugin"`, `order = 100`, `iconName = "command"`, `policy = .disabled`, `label = "widgetControl"`.
  - `AudioWidgetControlViewModel` — reads pending widget commands and dispatches playback/navigation.
  - `AudioWidgetCommandObserver` — triggers command handling.
  - `AudioWidgetCommandStore` — shared `UserDefaults` store for widget triggers.
  - `AudioWidgetControlRootView` — background view attached to the root view.
  - `AudioWidgetPlaybackCapability` / `Adapter` — narrows `PlaybackProviding`.
  - `AudioWidgetPlaybackRequestPolicy` / `AudioWidgetPlayPauseAction` — pure command policy (command counting, odd/even play-pause, result applicability).
  - `AudioWidgetEvents`, `AudioWidgetControlPluginInfo`.
- **Plugin registration**: Registers with ID `AudioWidgetControlPlugin`. `onReadyAsync` resolves `PlaybackProviding` and `AudioTrackNavigationProviding`, builds the view model with `nextAsset`/`previousAsset`/`firstAsset`/`lastAsset` closures, and starts the observer. `addRootView(content:)` attaches `AudioWidgetControlRootView` as a background to the content.
- **Workflow / data flow**:
  1. A widget writes a trigger (count) into shared `UserDefaults`; the view model observes and drains it.
  2. Play-pause toggles only on odd repeated commands (even rapid taps cancel out); the command is always consumed, even when no playback capability is present.
  3. Next/Previous resolve a URL through the navigation provider and play it; Previous at the start wraps to the last asset in repeat-all mode. In-flight navigation waits for the previous task.
  4. Results only apply when the current asset has not changed (matching symlinked assets, but not distinct dangling symlinks). Command counts are capped (e.g. 10) and legacy timestamp triggers are treated as a single command.
- **Dependencies** (from `Package.swift`): `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `ProviderDocsView`, `ProviderAudioLibrary`, `MagicPlayMan`, `ProviderPlayback`, `ProviderAudioNavigation`. Resources: `Localizable.xcstrings`.

## Testing Logic

- **Test files**: `Tests/AudioWidgetControlPluginTests.swift`.
- **Key scenarios tested**:
  - Metadata: `iconName == "command"`; title/description non-empty.
  - `AudioWidgetPlaybackRequestPolicy`: navigation results only apply to an unchanged current asset (symlinked asset matches; distinct dangling symlinks do not); waits for an in-flight navigation task; command counting preserves rapid repeats (caps at 10, handles legacy timestamp/NSNumber triggers, ignores unexpected types); command consumption preserves commands added during handling; play-pause acts only on odd repeated commands.
  - `AudioWidgetControlViewModel`: odd play-pause toggles and clears the trigger; even play-pause is a no-op but still consumes the command; next navigates to the adjacent asset; previous wraps to the last asset in repeat-all; a missing playback capability still consumes the pending command.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioWidgetControl
  swift test
  ```
