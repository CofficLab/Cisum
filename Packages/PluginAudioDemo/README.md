# PluginAudioDemo

Demo-mode audio plugin for Cisum. It contributes a placeholder "Music Repository" tab populated with synthetic demo audio items, used to preview the audio UI without a real library or storage.

## Functional Logic

- **Core responsibility**: Provide a self-contained demo audio list and add button for when the app runs in demo mode. It does not touch the real database; it renders a fixed set of sample items so the music scene UI can be exercised without user media.
- **Key types / protocols**:
  - `AudioDemoPlugin` — plugin entry (`AsyncSuperPlugin`, `SuperLog`), `id = "AudioDemoPlugin"`, `order = 1`, `iconName = "externaldrive"`, `policy = .disabled`.
  - `AudioDemoPluginInfo` — metadata: `title`, `description`, `tabLabel` ("Music Repository"), `iconName`.
  - `AudioListDemo` — the demo list view (20 built-in demo audio files), optionally showing an add button.
  - `AudioItemDemo` — a single demo row; exposes `iconNames` (8 icons) and `stableIndex(for:count:)`.
  - `AudioDemoAddButton` — triggers the importing state via `AppStateProviding`.
  - About/Manual docs views.
- **Plugin registration**: Registers with ID `AudioDemoPlugin`. `onBootAsync` contributes `addTabView(reason:demoMode:)`. The tab is only returned when the current scene is `.music` **and** `demoMode` is true; otherwise it contributes nothing. `onReadyAsync` resolves `SceneProviding` into a weak `SceneBox`.
- **Workflow / data flow**:
  1. The kernel asks for tab contributions; the plugin guards on music scene and demo mode.
  2. `AudioListDemo` renders the fixed demo set; on non-desktop platforms it also injects an `AudioDemoAddButton` that toggles `isImporting` on `AppStateProviding`.
  3. `AudioItemDemo.stableIndex(for:count:)` maps a hash to a stable icon index, including defensive handling of extreme/out-of-range values.
- **Dependencies** (from `Package.swift`): `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `ProviderDocsView`, `ProviderScene`. Resources: `Localizable.xcstrings`.

## Testing Logic

- **Test files**: `Tests/AudioDemoPluginTests.swift`.
- **Key scenarios tested**:
  - Plugin metadata is stable: `iconName == "externaldrive"`, and title/description/tabLabel are non-empty.
  - Demo content availability: `AudioListDemo.demoAudioFiles.count == 20` and `AudioItemDemo.iconNames.count == 8`.
  - `AudioItemDemo.stableIndex(for:count:)` handles extreme hashes safely — returns a valid index for `Int.min`, wraps negatives (e.g. `-1 → 7`), handles in-range values (e.g. `9 → 1`), and degrades to `0` when the icon count is zero.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioDemo
  swift test
  ```
