# Audio Provider/Plugin Boundary Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Audio providers contract-only and move all persistence, storage, filesystem, repository, and event-publishing implementations into plugins.

**Architecture:** `ProviderAudioLibrary`, `ProviderAudioLike`, and `ProviderAudioNavigation` will expose narrow, typed contracts and transport-safe models only. `PluginAudioDBData` will be the sole owner of the audio catalog implementation and will register the concrete capabilities with the kernel. Feature plugins will resolve those capabilities during lifecycle assembly and inject them into their view models/services; no feature plugin will construct or discover an audio repository through a global host.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftData, SwiftUI, KernelCore provider registry, Swift Testing.

---

### Task 1: Freeze the target contracts

**Files:**
- Modify: `Packages/ProviderAudioLibrary/Sources/ProviderAudioLibrary/AudioLibraryProviding.swift`
- Create/modify: `Packages/ProviderAudioLibrary/Sources/ProviderAudioLibrary/AudioLibraryModels.swift`
- Modify: `Packages/ProviderAudioNavigation/Sources/ProviderAudioNavigation/AudioTrackNavigationProviding.swift`
- Create: `Packages/ProviderAudioLibrary/Sources/ProviderAudioLibrary/AudioLibraryOrderingProviding.swift`
- Create: `Packages/ProviderAudioLibrary/Sources/ProviderAudioLibrary/AudioLibrarySyncProviding.swift`

Define narrow async capabilities for catalog reads, deletion/sync, ordering, and navigation. No contract may expose `AudioRepo`, SwiftData types, `ObservableObject`, or `NotificationCenter` names. Define typed event payloads and transport-safe audio item/diagnostic models.

Run the affected provider package tests and add contract tests for empty/no-op implementations and event cancellation semantics.

### Task 2: Move the catalog implementation into `PluginAudioDBData`

**Files:**
- Move: `ProviderAudioLibrary` SwiftData model, database actor, repository, container factory, filesystem URL helpers, and implementation errors into `Packages/PluginAudioDBData/Sources`
- Modify: `Packages/PluginAudioDBData/Package.swift`
- Modify: `Packages/PluginAudioDBData/Sources/AudioLibraryProvider.swift`
- Modify: `Packages/PluginAudioDBData/Sources/AudioDBDataPlugin.swift`
- Modify: `Packages/PluginAudioDBData/Tests/*`

Keep the concrete SwiftData schema and `AudioRepo` internal to the data plugin. Make `AudioLibraryProvider` the single cached adapter and register every public capability from the same cached implementation. Move event publication here and emit the typed provider events from the adapter.

Run `swift test --package-path Packages/PluginAudioDBData` after the move and preserve the existing catalog behavior tests.

### Task 3: Move like persistence behind `PluginAudioLike`

**Files:**
- Modify: `Packages/ProviderAudioLike/Sources/ProviderAudioLike/*`
- Modify: `Packages/PluginAudioLike/Package.swift`
- Create/modify: `Packages/PluginAudioLike/Sources/AudioLikeProvider.swift`
- Modify: `Packages/PluginAudioLike/Sources/AudioLikePlugin.swift`
- Modify: `Packages/PluginAudioLike/Sources/ViewModels/AudioLikeViewModel.swift`
- Modify: `Packages/PluginAudioLike/Tests/*`

Keep only like contracts and DTOs in `ProviderAudioLike`. Move the SwiftData model, actor repository, configuration singleton, and localized implementation errors into the plugin. Register one `AudioLikeProviding` instance and inject it into the plugin view model and the catalog implementation rather than calling `AudioLikeRepo.shared` from another provider.

Run the like package tests and the catalog tests together to verify configuration changes and cross-plugin like updates.

### Task 4: Remove the global AudioPluginHost path

**Files:**
- Delete: `Packages/ProviderAudioLibrary/Sources/ProviderAudioLibrary/Models/AudioPluginHost.swift`
- Modify: `Packages/PluginAudio/Sources/AudioPlugin.swift`
- Modify: `Packages/PluginAudio/Sources/ViewModels/AudioRootViewModel.swift`
- Modify: `Packages/PluginAudioSettings/Sources/*`
- Modify: `Packages/PluginAudioJob/Sources/*`
- Modify: `Packages/PluginAudioCopy/Sources/*`
- Modify: `Packages/PluginAudioPlayMode/Sources/*`
- Modify: `Packages/PluginAudioProgress/Sources/*`
- Modify: `Packages/PluginAudioWidgetControl/Sources/*`

Resolve the registered contracts from `CisumKernel` in each plugin's `onReady`/enable assembly. Inject only the required capability into each service or view model. Remove static repository construction, storage URL closures, and compatibility exports from `PluginAudio`.

Run repository-wide searches to ensure no production source references `AudioPluginHost`, `AudioRepo`, or `AudioLikeRepo.shared` outside their owning implementation plugin.

### Task 5: Normalize event ownership and diagnostics

**Files:**
- Modify: `Packages/ProviderAudioLibrary/Sources/ProviderAudioLibrary/Events/AudioEvent.swift`
- Modify: `Packages/PluginAudioDBView/Sources/Observers/AudioDatabaseObserver.swift`
- Modify: `Packages/PluginAudioProgress/Sources/Observers/AudioProgressObserver.swift`
- Modify: `Packages/PluginAudioControlButtons/Sources/Observers/ControlButtonsObserver.swift`
- Modify: `Packages/PluginAudioDBView/Sources/Support/AudioDBDependencies.swift`
- Modify: `Packages/PluginAudioDBData/Sources/*`

Replace broad global audio notifications with typed provider event subscriptions. Keep copy/download/progress events in their owning plugins. Keep diagnostic values as pure models, but build them in the data/storage plugin rather than probing `UserDefaults`, iCloud, and `FileManager` from a provider contract package.

### Task 6: Add architectural enforcement

**Files:**
- Modify: `Scripts/check-plugin-boundaries.sh`
- Modify: `docs/codemaps/architecture.md`
- Modify: `docs/architecture/plugin-boundaries.md`

Extend the checks to reject provider source imports of SwiftData, SwiftUI, OSLog, and implementation-only audio packages; reject `AudioPluginHost` and concrete repository access from non-owning production plugins; and verify that only `FactoryCisum` assembles the concrete audio plugins.

### Task 7: Full verification

Run:

```bash
./Scripts/check-plugin-boundaries.sh
swift test --package-path Packages/ProviderAudioLibrary
swift test --package-path Packages/ProviderAudioLike
swift test --package-path Packages/ProviderAudioNavigation
swift test --package-path Packages/PluginAudioDBData
swift test --package-path Packages/PluginAudio
swift test --package-path Packages/PluginAudioDBView
swift test --package-path Packages/PluginAudioLike
swift test --package-path Packages/PluginAudioProgress
swift test --package-path Packages/PluginAudioJob
swift test --package-path Packages/PluginAudioCopy
swift test --package-path Packages/PluginAudioPlayMode
swift test --package-path Packages/PluginAudioWidgetControl
```

Also run the relevant Cisum Xcode build/scheme if available and update the architecture codemap with the final dependency graph.

## Implementation status

Completed on 2026-09-10:

- ProviderAudioLibrary and ProviderAudioLike now contain only contracts, typed events, DTOs, metadata, and pure diagnostic models.
- AudioDB/AudioRepo/AudioModel/AudioConfigRepo and the internal event bridge moved to PluginAudioDBData.
- AudioLikeModel/AudioLikeRepo/configuration moved to PluginAudioLike behind AudioLikeProviding.
- AudioPluginHost and static repository construction were removed; consumers resolve Kernel providers.
- Storage/database/delete/progress observers now use typed StorageProviding or AudioLibraryProviding events.
- Boundary checks and architecture codemaps were updated.
- Provider, DBData, Like, DBView, Root, and Kernel tests pass; FactoryCisum builds successfully.
