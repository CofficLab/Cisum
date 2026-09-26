# PluginBookSettings

The audiobook settings plugin for Cisum. It contributes an "Audiobook Settings"
pane to the app's settings window that shows the library location (iCloud vs local),
library size, file count, and (on macOS) an "Open in Finder" action.

## Functional Logic

- **Core responsibility:** surface book-library disk metrics in the settings window
  and refresh them when the storage location changes. It does not change playback
  preferences itself; those live in `ProviderBook`.
- **Key types/protocols:**
  - `BookSettingsPlugin` — `AsyncSuperPlugin`, `SuperLog`; singleton `shared`,
    `id = "BookSettingsPlugin"`, `order = 11`, `iconName = "gearshape"`,
    `category = .system`, `policy = .disabled`.
  - `BookSettingsPluginInfo` — title "Audiobook Settings", description "Audiobook
    plugin settings", `iconName = "gearshape"`, `emoji = "🔊"`, `order = 11`.
  - `BookSettingsViewModel` — `ObservableObject`; `@Published` `refreshToken`, `disk`,
    `description`, `diskSize`, `fileCount`; `handleStorageLocationChanged()` bumps
    the token; `refresh()` re-reads the disk and computes size/file count off the
    main thread with a generation guard.
  - `BookSettingsObserver` — subscribes the book provider's
    `.storageLocationChanged` event and forwards it to the view model.
  - `BookSettingsView` — public settings content: library size row, optional
    "Open Library" Finder row (macOS only), file-count row (with singular/plural).
  - Supporting types: `BookLibraryMetrics`, `BookSettingsMetricsPolicy`
    (`shouldApplyMetrics(currentDisk:requestedDisk:currentGeneration:resultGeneration:)`
    — guards stale async results), `BookSettingsFileCountTextPolicy`
    (`shouldUseSingular(_:)` true only for count == 1).
  - `BookSettingsPluginView` — thin wrapper injected as the settings destination.
- **Plugin registration:** registered as `BookSettingsPlugin`. In `onRegister` it adds
  About/Manual docs. In `onBootAsync` it registers a settings navigation item
  (`id = "book-settings"`, icon "book") whose destination is
  `BookSettingsPluginView`. `onEnable` re-installs state; `onDisable` tears it down;
  `onShutdownAsync` removes contributions. State is built lazily from
  `BookDatabaseProviding.bookDisk`.
- **Workflow/data flow:** settings opens → `BookSettingsViewModel.refresh()` → reads
  the current `bookDisk`, labels it iCloud vs local, and spawns a detached task to
  compute readable size and recursive file count; the result is applied only if the
  disk and generation are still current. A `.storageLocationChanged` event bumps
  `refreshToken`, which re-runs `refresh()`.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`,
  `ProviderDocsView`, `ProviderBook`.

## Testing Logic

- **Test files:**
  - `Tests/BookSettingsPluginTests.swift` — metadata, policy, view helpers, and
    view-model tests.
- **Key scenarios tested:**
  - Metadata: `iconName == "gearshape"`, `order == 11`.
  - `BookSettingsMetricsPolicy`: applies metrics only when the current disk, requested
    disk, and generation all match; rejects mismatched disk, stale generation, and
    nil current disk.
  - `BookSettingsView.shouldShowOpenLibraryAction`: hidden for a missing local disk,
    shown for an existing one.
  - `BookSettingsView.shouldUseSingularFileCount`: true only for count == 1.
  - ViewModel: empty initial state; `handleStorageLocationChanged` bumps
    `refreshToken`; `refresh()` with nil disk clears metrics; `refresh()` on a local
    directory collects real size and file count (waits for the detached task); a
    stale refresh result is discarded.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBookSettings
  swift test
  ```
