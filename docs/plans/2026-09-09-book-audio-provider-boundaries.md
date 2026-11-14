# Book and Audio Provider Boundaries Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove compile-time dependencies between Cisum feature plugins in the book and audio domains while preserving current behavior and making Provider, Observer, and Capability boundaries explicit.

**Architecture:** Keep all cross-plugin domain contracts and shared implementations in `Provider*` packages, keep feature lifecycle/UI/Observers/Capabilities in `Plugin*` packages, and reserve `*Kit` packages for business-agnostic infrastructure. Only `FactoryCisum` may assemble all concrete plugin targets. Existing observers remain owned by their feature plugin, while external operations are exposed through the existing per-plugin capabilities and provider adapters.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftData, SwiftUI, KernelCore provider registry, Testing.

### Implementation status

Completed on 2026-09-09:

- Book, audio library, audio-like, and store implementations now live in `ProviderBook`, `ProviderAudioLibrary`, `ProviderAudioLike`, and `ProviderStore`.
- Book/audio feature packages now depend on neutral core/provider products instead of sibling `Plugin*` modules.
- AudioDB registers the `ProviderAudioLibrary` adapter; storage observers and playback/copy capabilities remain owned by their respective feature plugins.
- `Scripts/check-plugin-boundaries.sh` verifies the dependency rule and currently passes.
- Verified builds and tests for the changed book/audio/store packages; `PluginAudio` (38), `PluginBook` (50), `PluginBookProgress` (35), `PluginAudioLike` (11), and `PluginStore` (13) test cases pass.

---

### Task 1: Split the book package into provider and plugin targets

**Files:**
- Modify: `Packages/PluginBook/Package.swift`
- Modify: `Packages/PluginBook/Sources/BookPlugin.swift`
- Modify: `Packages/PluginBook/Sources/ViewModels/BookRootViewModel.swift`
- Modify: `Packages/PluginBook/Sources/Views/BookRootView.swift`
- Modify: `Packages/PluginBook/Sources/Observers/BookStorageObserver.swift`
- Create: `Packages/PluginBook/Sources/ProviderExports.swift`
- Modify: `Packages/PluginBook/Tests/BookPluginTests.swift`

**Step 1: Add a `ProviderBook` product/target containing the book models, DTOs, database, repository, events, host bridge, and domain errors.**

**Step 2: Restrict the `PluginBook` target to its lifecycle entry point, root state, observer, and views, and make it depend on `ProviderBook`.**

**Step 3: Add explicit `import ProviderBook` statements and retain a small compatibility export only inside the plugin target.**

**Step 4: Run `swift test --package-path Packages/PluginBook` and fix target visibility issues.**

### Task 2: Migrate book feature plugins to `ProviderBook`

**Files:**
- Modify: `Packages/PluginBookDBView/Package.swift` and book DB sources
- Modify: `Packages/PluginBookProgress/Package.swift` and progress sources
- Modify: `Packages/PluginBookSettings/Package.swift` and settings sources
- Modify: `Packages/PluginBookControlButtons/Package.swift` and control sources
- Modify: `Packages/PluginBookLike/Package.swift` and like sources
- Modify: `Packages/PluginBookPlayMode/Package.swift` and play-mode sources
- Modify: `Packages/PluginBookScene/Package.swift` and scene sources as needed

**Step 1: Replace `PluginBook` imports and product dependencies with `ProviderBook`.**

**Step 2: Remove unused `PluginBookScene` dependencies from feature plugins; resolve scene state through `ProviderScene`.**

**Step 3: Keep every feature plugin's existing `Observers/` and `Capabilities/` as the only external state/action boundary.**

**Step 4: Run each affected package test independently.**

### Task 3: Split the audio core and like persistence targets

**Files:**
- Modify: `Packages/PluginAudio/Package.swift`
- Modify: `Packages/PluginAudio/Sources/Services/AudioRepo.swift`
- Modify: `Packages/PluginAudio/Sources/AudioPlugin.swift`
- Modify: `Packages/PluginAudioLike/Package.swift`
- Modify: `Packages/PluginAudioLike/Sources/Services/AudioLikeRepo.swift`
- Modify: `Packages/PluginAudioLike/Sources/Models/AudioLikeModel.swift`
- Create: `Packages/PluginAudioLike/Sources/ProviderAudioLikeExports.swift`

**Step 1: Consolidate audio models, repositories, configuration, events, and storage diagnostics in `ProviderAudioLibrary`.**

**Step 2: Move like models and persistence to `ProviderAudioLike`, and make `ProviderAudioLibrary` depend on this Provider rather than `PluginAudioLike`.**

**Step 3: Restrict `PluginAudio` and `PluginAudioLike` targets to plugin lifecycle, observers, capabilities, view models, and views.**

**Step 4: Run the audio core and like package tests before migrating consumers.**

### Task 4: Migrate audio feature plugins away from plugin modules

**Files:**
- Modify: `Packages/PluginAudioDBView/Package.swift` and sources
- Modify: `Packages/PluginAudioProgress/Package.swift` and sources
- Modify: `Packages/PluginAudioPlayMode/Package.swift` and sources
- Modify: `Packages/PluginAudioSettings/Package.swift` and sources
- Modify: `Packages/PluginAudioJob/Package.swift` and sources
- Modify: `Packages/PluginAudioWidgetControl/Package.swift` and sources
- Modify: `Packages/PluginAudioCopy/Package.swift` and sources
- Modify: `Packages/PluginAudioLike/Package.swift` and sources
- Modify: `Packages/PluginAudioDemo/Package.swift` and sources as needed

**Step 1: Replace `import PluginAudio` with `import ProviderAudioLibrary` where data/repository APIs are still required.**

**Step 2: Replace `import PluginAudioLike` with `import ProviderAudioLike` where persistence APIs are required.**

**Step 3: Remove all feature-plugin imports of other feature plugins, including unused scene imports.**

**Step 4: Preserve existing observer ownership and capability adapters; do not reintroduce static plugin host access into views or view models.**

**Step 5: Run all affected package tests.**

### Task 5: Add an architectural dependency check

**Files:**
- Create: `Scripts/check-plugin-boundaries.sh`
- Modify: `README.md` or `docs/codemaps/architecture.md`

**Step 1: Check that feature plugin source files do not import another `Plugin*` module.**

**Step 2: Allow plugin-to-plugin references only in Factory targets and tests that explicitly exercise factory composition.**

**Step 3: Run the check against the full repository and document the command.**

### Task 6: Full verification

**Step 1: Run the boundary check.**

**Step 2: Run tests for all changed packages.**

**Step 3: Run the relevant Cisum Xcode scheme/build if available.**

**Step 4: Review the final dependency graph and update the architecture codemap with the new target layering.**
