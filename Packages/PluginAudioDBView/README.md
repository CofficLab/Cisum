# PluginAudioDBView

The audio database viewer plugin. It provides the browsable "Music Repository" content tab, the audio list / tree browser, item rows, and the settings-page entry for the audio library, consuming the data layer through `AudioLibraryProviding` rather than owning the database.

## Functional Logic

- **Core responsibility**: Render the audio library UI — a paginated track list, a directory tree browser, per-item rows with file sizes, add/import entry points, and a settings view — and wire list interactions (play, delete, sort) to the playback and library providers.
- **Key types / protocols**:
  - `AudioDBViewPlugin` — plugin entry (`AsyncSuperPlugin`, `SuperLog`), `id = "AudioDBViewPlugin"`, `order = 1`, `iconName = "externaldrive"`, `policy = .alwaysOn`.
  - Views: `AudioDBPluginRootView`, `AudioDBPluginTabView`, `AudioDBRootView`, `AudioDBView`, `AudioDBSettingView`, `AudioTreeView`, `AudioList`, `AudioItemView`, `AudioDBTips`, `BtnAdd`, plus About/Manual docs views.
  - View models: `AudioListViewModel` (paginated list + playback), `AudioDBRootViewModel`, `AudioDBViewModel`, `AudioTreeViewModel`.
  - Models/state: `AudioTreeNode`, `AudioTreeBuilder`, `AudioDBDependencies`, `AudioDBSceneState`, `AudioStorageDiagnosticsFactory`.
  - Observers: `AudioDatabaseObserver` (library events → list/root/db), `AudioDBPlaybackObserver` (playback events → list), `AudioDBSceneObserver` (scene gate).
  - Policies: `AudioListLoadPolicy` (pagination/generation/dedup), `AudioListDeletionPolicy`, `AudioDeletePlaybackPolicy`, `AudioPlaybackCapability`/`Adapter`, `AudioItemFileSize*` policies.
- **Plugin registration**: Registers with ID `AudioDBViewPlugin`. `onBootAsync` contributes a tab view (`addTabView`, labeled "Music Repository", only when the current scene is `.music` and not in demo mode) and a settings navigation item (`addSettingNavigationItem`, id `"audiodb"`). `onReadyAsync` assembles view models and observers — deliberately resolving `SceneProviding` at ready (not boot) because the scene provider instance is replaced by `ScenePlugin` during its own `onReady`.
- **Workflow / data flow**:
  1. The root/tab views pull a narrow set of closures (`audioLibrary`, `audioDisk`, `audioDiagnostics`) from the kernel rather than holding the kernel; view models never retain the kernel.
  2. `AudioListViewModel` loads tracks in pages, dedupes symlinked rows, rebases pagination after deletions, and discards stale load results via generation counters.
  3. Playback actions on a row go through `AudioPlaybackCapabilityAdapter`; deleting the currently-playing track follows `AudioDeletePlaybackPolicy`.
  4. The settings page uses its own independent `AudioListViewModel`/`AudioTreeViewModel` so its on-appear reload does not flash the main content view. A weak `SceneBox` guards all scene-gated contributions.
- **Dependencies** (from `Package.swift`): `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `ProviderDocsView`, `ProviderPlayback`, `ProviderAudioLibrary`, `ProviderScene`, `ProviderStorage`. Resources: `Localizable.xcstrings`.

## Testing Logic

- **Test files**:
  - `Tests/AudioDBViewPluginTests.swift` — list/pagination/import policy logic and metadata.
  - `Tests/AudioDBViewCoverageTests.swift` — diagnostics factory, tree builder, and tree view model coverage.
  - `Tests/AudioDBViewPluginSceneTests.swift` — scene-provider resolution timing regression.
- **Key scenarios tested**:
  - `AudioDBViewModel.sortMode` parsing trims whitespace and falls back to `.none`.
  - Import cleanup: copied files are removed when a batch fails or the repository is unavailable; symlinked files are copied as standalone regular files; destination names avoid dangling symlinks.
  - `AudioListLoadPolicy`: next-load offset, page advancement, no-skip after displayed rows shrink, page rebasing after deletion, generation checks, symlink dedup, has-more detection, stale-result handling, and load-more triggering by visible index.
  - `AudioListDeletionPolicy`: matches symlinked/dangling-symlink rows, counts only displayed removed rows, updates totals for unloaded deleted rows, and invalidates pending loads.
  - `AudioStorageDiagnosticsFactory`: reads storage root and builds the audio disk path, falling back when storage is missing.
  - `AudioTreeBuilder`: scans files and folders (directories first, hidden and unsupported files skipped), returns empty for a missing directory, case-insensitive extension checks, and `AudioTreeNode` computed properties.
  - Scene regression: the music tab is contributed only with the live scene provider resolved at `onReady`, scene switches gate contribution, and duplicate scene registration throws until unregistered.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioDBView
  swift test
  ```
