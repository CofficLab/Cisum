# Audio Database Sync Ownership Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `PluginAudioDBData` own the audio filesystem-to-database synchronization lifecycle so catalog correctness does not depend on `PluginAudioJob`.

**Architecture:** Move the existing filesystem monitor and storage-change restart logic into `PluginAudioDBData`. The data plugin will create the monitor after its `AudioLibraryProvider` is registered, and the monitor will call the provider's internal synchronization adapter directly. `ProviderAudioLibrary` remains contract-only. Since the current `PluginAudioJob` has no independent production responsibility beyond this monitor, remove it from the package graph and factory.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftData, Combine filesystem monitoring, KernelCore plugin lifecycle, Swift Testing.

---

### Task 1: Move the monitor implementation into the data plugin

**Files:**
- Move: `Packages/PluginAudioJob/Sources/Jobs/FileSystemMonitorJob.swift` to `Packages/PluginAudioDBData/Sources/Implementation/AudioFileSystemMonitor.swift`
- Modify: `Packages/PluginAudioDBData/Package.swift`
- Modify: `Packages/PluginAudioDBData/Sources/AudioDBDataPlugin.swift`
- Modify: `Packages/PluginAudioDBData/Sources/AudioLibraryProvider.swift`
- Create/modify: `Packages/PluginAudioDBData/Tests/AudioDBPluginTests.swift`

Keep the race-protection and full-sync decision tests. Rename the type to reflect data synchronization rather than a generic audio job. Start the monitor from `AudioDBDataPlugin.onReady`, stop it during disable/shutdown, and restart it when the storage provider changes. The monitor must resolve the current disk and repository through the data plugin's own provider, not through `CisumKernel.audioLibrary` or another plugin.

### Task 2: Remove the obsolete audio-job package

**Files:**
- Delete: `Packages/PluginAudioJob`
- Modify: `Packages/FactoryCisum/Package.swift`
- Modify: `Packages/FactoryCisum/Sources/FactoryCisum/PluginFactory.swift`
- Modify: `Scripts/check-plugin-boundaries.sh`
- Modify: `docs/codemaps/architecture.md`

Remove `AudioJobPlugin` from the default plugin list and remove the package dependency. Do not move the unused generic scheduler/manager into the data layer unless production code actually requires it; the data plugin should own one focused synchronization coordinator instead of preserving an unrelated job framework.

### Task 3: Update documentation and boundary checks

**Files:**
- Modify: `Packages/PluginAudioDBData/README.md`
- Modify: `docs/architecture/plugin-boundaries.md`
- Modify: `docs/codemaps/data.md`

Document that the data plugin owns initial reconciliation, filesystem monitoring, storage relocation handling, and deletion synchronization. Ensure boundary checks reject stale `PluginAudioJob` references and continue to enforce contract-only Provider packages.

### Task 4: Verify behavior and dependency ownership

Run:

```bash
./Scripts/check-plugin-boundaries.sh
swift test --package-path Packages/PluginAudioDBData
swift test --package-path Packages/FactoryCisum
rg -n "PluginAudioJob|AudioJobPlugin|FileSystemMonitorJob|AudioJobManager|AudioJobScheduler" Packages Scripts --glob '*.swift' --glob 'Package.swift' --glob '*.sh'
git diff --check
```

The search must not find production references to the removed plugin or old monitor types. Also build the affected package if `swift test` does not compile all production targets.

## Implementation status

Completed on 2026-09-11:

- `AudioFileSystemMonitor` and its restart/cancellation lifecycle now live in `PluginAudioDBData`.
- `PluginAudioDBData` starts synchronization after registering its provider and rebuilds it on storage changes.
- `PluginAudioJob` and its unused generic job framework were removed from the package graph and factory.
- Data-layer reconciliation tests, the plugin boundary check, and the `FactoryCisum` build pass.
