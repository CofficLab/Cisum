# Strict Book Package Boundaries Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement the plan task-by-task.

**Goal:** Physically remove all book feature-plugin dependencies on the `PluginBook` package while preserving book behavior.

**Architecture:** Consolidate the cross-plugin `BookProviding` contract and book persistence/domain implementation into the existing `ProviderBook` package. `PluginBook` will contain only lifecycle, UI, and its storage observer; book feature plugins will depend only on `ProviderBook` and public infrastructure providers. `FactoryCisum` remains the composition root allowed to depend on concrete `Plugin*` plugins.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftData, SwiftUI, KernelCore provider registry, Testing.

---

### Task 1: Consolidate book provider implementation

**Files:**
- Create: `Packages/ProviderBook/Package.swift`
- Create: `Packages/ProviderBook/Sources/ProviderBook/BookProviding.swift`
- Modify: `Packages/ProviderBook/Package.swift`
- Move: book domain sources from `Packages/PluginBook/Sources/` into `Packages/ProviderBook/Sources/ProviderBook/`
- Move: `Packages/PluginBook/Resources/Localizable.xcstrings` into `Packages/ProviderBook/Resources/`

**Steps:**

1. Keep the Provider contract in `ProviderBook`.
2. Move `BookConfig`, `BookEvent`, `BookPluginError`, `BookPluginHost`, `BookPluginInfo`, DB, DTO, Models, and Repo into the same `ProviderBook` package.
3. Make `ProviderBook` depend only on public infrastructure packages.
4. Build `ProviderBook` before changing consumers.

### Task 2: Reduce `PluginBook` to the concrete plugin target

**Files:**
- Modify: `Packages/PluginBook/Package.swift`
- Modify: `Packages/PluginBook/Sources/ProviderExports.swift`
- Modify: `Packages/PluginBook/Sources/BookPlugin.swift`
- Modify: `Packages/PluginBook/Sources/ViewModels/BookRootViewModel.swift`
- Modify: `Packages/PluginBook/Sources/Views/BookRootView.swift`
- Modify: `Packages/PluginBook/Tests/BookPluginTests.swift`

**Steps:**

1. Replace the in-package book implementation with a package dependency on `ProviderBook`.
2. Keep only lifecycle, UI, and storage observer sources in `PluginBook`.
3. Keep compatibility exports only inside `PluginBook`.
4. Build and test `PluginBook`.

### Task 3: Migrate every book feature package

**Files:**
- Modify: `Packages/PluginBookDBView/Package.swift` and sources
- Modify: `Packages/PluginBookProgress/Package.swift` and sources/tests
- Modify: `Packages/PluginBookSettings/Package.swift` and sources
- Modify: `Packages/PluginBookControlButtons/Package.swift` and sources

**Steps:**

1. Replace `../PluginBook` dependencies with `../ProviderBook`.
2. Use the `ProviderBook` product for all shared book types.
3. Add explicit `import ProviderBook` where persistence/domain types are used.
4. Verify no book feature package has a `PluginBook` path or product dependency.

### Task 4: Enforce the physical package boundary

**Files:**
- Modify: `Scripts/check-plugin-boundaries.sh`
- Modify: `docs/architecture/plugin-boundaries.md`

**Steps:**

1. Check package manifests for sibling `PluginBook`, `PluginAudio`, or `PluginStore` package dependencies, excluding the Factory composition root and the plugin’s own package.
2. Document that target-level separation inside a plugin package is insufficient for cross-plugin reuse.
3. Run the boundary check and inspect the dependency graph.

### Task 5: Apply the same physical rule to audio and store providers

**Files:**
- Create: `Packages/ProviderAudioLike/Package.swift`
- Create: `Packages/ProviderStore/Package.swift`
- Modify: `Packages/ProviderAudioLibrary/Package.swift`
- Modify: `Packages/PluginAudio`, `Packages/PluginAudioLike`, `Packages/PluginStore`, and all audio feature manifests
- Modify: `Packages/PluginAudioCopy/Package.swift`

**Steps:**

1. Move audio-like, audio-library, and store implementations into `ProviderAudioLike`, `ProviderAudioLibrary`, and `ProviderStore`.
2. Update every audio/store feature package to depend on the corresponding Provider package.
3. Keep concrete plugin lifecycle products only in their own plugin packages and in `FactoryCisum`.

### Task 6: Verify behavior

**Steps:**

1. Build and test `ProviderBook`, `PluginBook`, `PluginBookDBView`, `PluginBookProgress`, `PluginBookSettings`, `PluginBookControlButtons`, `ProviderAudioLike`, `ProviderAudioLibrary`, and `ProviderStore`.
2. Run `git diff --check`.
3. Confirm the working tree contains only the intended strict-boundary changes.
