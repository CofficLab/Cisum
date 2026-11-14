# Remaining SwiftUI Environment Dependency Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement the plan task-by-task.

**Goal:** Remove the remaining business-owned SwiftUI `EnvironmentObject` and custom `Environment` dependencies from Cisum's database, storage, and plugin composition paths. Providers remain capability/data contracts, while each plugin owns its observers and view models and passes view inputs explicitly.

**Architecture:** Keep system-provided environment values such as `dismiss`, `openWindow`, `colorScheme`, `modelContext`, `widgetFamily`, and accessibility settings. Replace business dependencies with explicit view initializers and small plugin-owned input values. The plugin actor remains responsible for constructing and retaining observers/view models; views only render the supplied state and call supplied capabilities/actions. No plugin imports another plugin module.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Package Manager, XCTest.

---

### Task 1: Migrate AudioDB views to explicit inputs — completed

**Files:**
- Modify `Packages/PluginAudioDBView/Sources/AudioDBPlugin.swift`
- Modify `Packages/PluginAudioDBView/Sources/Views/AudioDBPluginContainerViews.swift`
- Modify `Packages/PluginAudioDBView/Sources/Views/AudioDBRootView.swift`
- Modify `Packages/PluginAudioDBView/Sources/Views/AudioDBView.swift`
- Modify `Packages/PluginAudioDBView/Sources/Views/AudioDBSettingView.swift`
- Modify `Packages/PluginAudioDBView/Sources/Views/AudioList.swift`
- Modify `Packages/PluginAudioDBView/Sources/Views/AudioItemView.swift`
- Modify `Packages/PluginAudioDBView/Sources/Views/AudioTreeView.swift`
- Modify `Packages/PluginAudioDBView/Sources/Views/AudioDBTips.swift`
- Modify `Packages/PluginAudioDBView/Sources/Views/BtnAdd.swift`
- Modify `Packages/PluginAudioDBView/Sources/Support/AudioDBDependencies.swift`

1. Add explicit initializers for view models and `AudioDBDependencies`; pass them through root, tab, setting, list, tree, item, tips, and add-button views.
2. Remove `@EnvironmentObject`, `audioDBDependencies`, and the corresponding `.environmentObject`/`.environment` injections.
3. Preserve the existing `AudioDatabaseObserver` ownership and lifecycle in `AudioDBViewPlugin`; do not make a view create or own a provider/observer.
4. Add focused initializer/default-value coverage where practical so previews and tests do not depend on an implicit environment.

### Task 2: Migrate BookDB views to explicit inputs — completed

**Files:**
- Modify `Packages/PluginBookDBView/Sources/BookDBViewPlugin.swift`
- Modify `Packages/PluginBookDBView/Sources/Views/BookDBView.swift`
- Modify `Packages/PluginBookDBView/Sources/Views/BookDBViewDependencies.swift`
- Modify `Packages/PluginBookDBView/Sources/Views/BookDBDependencies.swift`
- Modify `Packages/PluginBookDBView/Sources/Views/BookDBSettingView.swift`
- Modify `Packages/PluginBookDBView/Sources/Views/BookList.swift`
- Modify `Packages/PluginBookDBView/Sources/Views/BookGrid.swift`
- Modify `Packages/PluginBookDBView/Sources/Views/BookTile.swift`
- Modify `Packages/PluginBookDBView/Sources/Views/BookTreeView.swift`
- Modify `Packages/PluginBookDBView/Sources/Views/BookDBTips.swift`

1. Pass `BookListViewModel`, `BookGridViewModel`, and `BookTreeViewModel` explicitly from the plugin composition boundary.
2. Pass `BookDBViewDependencies` explicitly to the main view tree and replace the import action environment with an explicit closure/local state boundary.
3. Remove the book database custom environment keys and all environment-object injection sites while retaining system `colorScheme` where it is only presentation context.
4. Keep book repository access behind `ProviderBook` capability types and preserve observer-owned refresh behavior.

### Task 3: Migrate PluginStorage business dependencies — completed

**Files:**
- Modify `Packages/PluginStorage/Sources/StorageDependencies.swift`
- Modify `Packages/PluginStorage/Sources/Migrate/MigrationProgressView.swift`
- Modify `Packages/PluginStorage/Sources/Migrate/RepositoryInfoView.swift`
- Modify the plugin composition call sites that construct these views.

1. Replace `pluginStorageDependencies` environment reads with explicit `StoragePluginDependencies` inputs.
2. Ensure migration UI receives provider capabilities/actions from the storage plugin rather than resolving them from global view environment.
3. Delete the custom storage environment key once no call sites remain.

### Task 4: Remove remaining business custom environments at composition boundaries — completed

**Files:** locate with `rg` before editing, primarily `Packages/FactoryCisum/Sources/FactoryCisum/Views/KernelRootView.swift`, `Packages/ProviderSettings/Sources/ProviderSettings/SettingsWindow.swift`, scene and toast composition files.

1. Classify each remaining custom environment value as system UI context, app-wide presentation context, or business capability.
2. Convert business capabilities/actions (`demoMode`, importing/show-database actions, theme selection state, scene/toast providers, and similar values) to explicit composition inputs or plugin/provider-owned state.
3. Keep only legitimate SwiftUI/system environment values and presentation-local state in the environment.
4. Remove obsolete custom keys and injection modifiers.

### Task 5: Strengthen architecture checks — completed

**Files:**
- Modify the existing architecture/boundary check script found by `rg --files | rg 'boundary|architecture|check'`.
- Add or modify focused tests under the affected package test targets.

1. Check all `Packages/Plugin*` source trees for imports of sibling plugin modules, not just the previously enumerated plugin subset.
2. Check the plugin source trees for business `@EnvironmentObject` and custom dependency environment keys while allowing documented system environment values.
3. Add regression coverage for the explicit construction paths that previously failed with missing `MagicPlayMan`/view-model environment objects.

### Task 6: Verify and hand off — completed

1. Run formatting/lint checks available in the repository.
2. Build the affected packages and run their tests, then run the repository-level test/build command if available.
3. Inspect `git diff` and `git status` to ensure the user's pre-existing localization edits remain intact.
4. Report remaining legitimate system environment uses separately from any unresolved business dependency.

Verification result: affected SwiftPM packages, the testable package targets, and the
`Cisum` macOS Xcode scheme all build successfully. The boundary check passes. The only
non-system environment remaining is MagicPlayMan's internal localization context; it is
not a plugin/business capability lookup and is outside this migration scope.
