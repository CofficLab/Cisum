# PluginAudioSettings

Audio settings plugin for Cisum. It contributes the "Audio Settings" entry to the settings navigation and displays the library storage location, disk metrics (file count, size), and an open-library action.

## Functional Logic

- **Core responsibility**: Surface audio-library settings — where the library lives, how many files it holds and how much space it uses, and the action to open the library folder — refreshing when the storage location changes.
- **Key types / protocols**:
  - `AudioSettingsPlugin` — plugin entry (`AsyncSuperPlugin`, `SuperLog`), `id = "AudioSettingsPlugin"`, `order = 10`, `iconName = "gearshape"`, `category = .system`, `policy = .disabled`.
  - `AudioSettingsViewModel` — holds `disk`, `description`, `fileCount`, `diskSize`, and a `refreshToken`; collects metrics and discards stale refreshes.
  - `AudioSettingsObserver` — watches `StorageProviding` and bumps refresh on location changes.
  - `AudioSettingsView` / `AudioSettingsPluginView` — settings UI.
  - `AudioSettingsMetricsPolicy` / `AudioSettingsFileCountTextPolicy` / `AudioLibraryMetrics` — metrics gating and text formatting.
  - `AudioSettingsPluginInfo` — metadata (title, description, icon, order).
- **Plugin registration**: Registers with ID `AudioSettingsPlugin`. `onBootAsync` contributes a settings navigation item (`addSettingNavigationItem`, id `"audio-settings"`, icon `"slider.horizontal.3"`). The view model's `audioDisk` closure is backed by `AudioLibraryProviding.audioDisk`; an `AudioSettingsObserver` is installed on `StorageProviding`.
- **Workflow / data flow**:
  1. The view model starts empty; storage-location changes bump `refreshToken` to trigger a reload.
  2. `refresh` with a usable local directory collects metrics (file count, size, localized "Local" description); when the disk becomes unavailable it clears all metrics.
  3. `AudioSettingsMetricsPolicy` only applies metrics for the current disk; stale refresh results (from a previous disk) are discarded via generation.
  4. The "open library" action is hidden when the disk is missing; file count uses singular wording only for exactly one file.
- **Dependencies** (from `Package.swift`): `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `ProviderDocsView`, `ProviderAudioLibrary`. Resources: `Localizable.xcstrings`.

## Testing Logic

- **Test files**: `Tests/AudioSettingsPluginTests.swift`.
- **Key scenarios tested**:
  - Metadata: `iconName == "gearshape"`, `order == 10`.
  - `AudioSettingsMetricsPolicy`: applies metrics only for the current disk, not for a changed or missing disk.
  - `AudioSettingsView`: hides the open-library action for a missing disk; uses singular file-count wording only for one file.
  - `AudioSettingsViewModel`: initial state is empty; a storage-location change bumps the refresh token; refresh without a disk clears metrics; refresh with a local directory collects file count and size; stale refresh results from a previous disk are discarded.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioSettings
  swift test
  ```
