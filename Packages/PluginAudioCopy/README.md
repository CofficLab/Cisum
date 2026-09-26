# PluginAudioCopy

Audio file copy / import plugin for Cisum (macOS only). It lets users drop audio files into the app and copies them into the audio library in the background, with batch task management, progress tracking, and drag-and-drop ingestion.

## Functional Logic

- **Core responsibility**: Import audio files into the Cisum library via background copy tasks. It owns the task queue, the copy worker, persistence of task state, and the drop/tip UI, and bridges to the audio library through `AudioLibraryProviding`.
- **Key types / protocols**:
  - `CopyPlugin` — plugin entry (`AsyncSuperPlugin`, `SuperLog`), `id = "CopyPlugin"`, `order = 0`, `iconName = "music.note"`, `policy = .disabled`. The whole class is compiled `#if os(macOS)` — it is a desktop-only feature.
  - `AudioCopyService` — static service facade that is configured at runtime with closures for `audioDiskProvider` and `audioCountProvider`; exposes the state view and root view.
  - `CopyWorker` — performs the actual file copies, planning unique destination names, resolving symlinks, and honoring task deletions.
  - `CopyDB` / `CopyTask` / `CopyTaskDTO` / `CopyTaskObserver` — task persistence and observation.
  - `CopyViewModel` — drives the task list and state.
  - `CopyRootView` (drop target), `CopyStateView`, `CopyList`, `BtnDelTask`, `AudioCopyTips` — UI.
  - Policies: `AudioCopyLimitPolicy` (how many tasks are allowed against the current library size), `CopyStatePresentation` (status message text), `CopyWorkerCompletionPolicy` / `CopyWorkerTaskPolicy` (lifecycle guards).
  - `AudioCopyPluginInfo` / `CopyEvents` — metadata and notifications.
- **Plugin registration**: Registers with ID `CopyPlugin`. `onRegister` adds About/Manual docs. `onBootAsync` contributes `addStateView()` via `PluginContributionProviding`. `addRootView(content:)` and `addStateView()` call `configureService()`, which wires `AudioCopyService` to the kernel-resolved `AudioLibraryProviding` (audio disk URL and total count).
- **Workflow / data flow**:
  1. Dropped files are validated against supported audio extensions; symlinked sources are canonicalized/deduplicated, while distinct dangling symlinks are kept separate.
  2. Sources are resolved from drag data (`FileURLDataProvider` first, falling back to the URL object representation).
  3. The worker copies files one by one into the library, planning unique destination names and copying the resolved symlink target as a regular file. Tasks deleted before start or after completion are skipped/discarded.
  4. Task count and DB-update notifications are posted on the main thread; `CopyStateView` summarizes pending/failed counts and exposes a details popover. A library-size limit caps the number of allowed incoming tasks.
- **Dependencies** (from `Package.swift`): `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `ProviderDocsView`, `ProviderAudioLibrary`, `ProviderStore`. Resources: `Localizable.xcstrings`.

## Testing Logic

- **Test files**: `Tests/AudioCopyPluginTests.swift`.
- **Key scenarios tested**:
  - Metadata: `AudioCopyPluginInfo.iconName`; task-count notification posts synchronously on the main thread.
  - Drag-and-drop: accepts only supported audio files (rejects folders/unsupported types); deduplicates symlinked sources but keeps distinct dangling symlinks; reads `FileURLDataProvider` with URL-object fallbacks (including after invalid/error `FileURLData`).
  - `CopyWorker`: plans unique destination names; avoids dangling-symlink destination names; copies the resolved symlink target; grants access to readable local sources without a security-scoped bookmark.
  - Presentation & list logic: `CopyStatePresentation` messages for pending/failed counts and details button labels; `CopyList.tasksToDelete` mapping index sets; `AudioCopyLimitPolicy` allowed task counts.
  - Guards: no-files alert after preparation failure, partial drop load failure reporting, infrastructure preparation only when sources exist, finished notification only when the queue empties, skip tasks deleted before start, discard completed copies for deleted tasks.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioCopy
  swift test
  ```
