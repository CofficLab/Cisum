# Playback Provider Observer Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove playback views' dependency on `MagicPlayMan` environment objects and make `ProviderPlayback` the capability/event boundary implemented by `PluginPlayBack`.

**Architecture:** `ProviderPlayback` owns playback contracts, neutral state data, event payloads, and cancellable observer handles. `PluginPlayBack` adapts `MagicPlayMan` into that contract and sends provider events. Feature plugins subscribe through their own `Observers/` types and update ViewModels; ProviderControlView remains a layout-only provider and receives UI slots from plugins.

**Tech Stack:** Swift 6 language mode, SwiftUI, Combine, Swift Package Manager, existing `KernelEventObserverStore` observer semantics.

---

### Task 1: Establish the playback provider boundary

**Files:**
- Modify: `Packages/ProviderPlayback/Sources/ProviderPlayback/PlaybackProviding.swift`
- Create: `Packages/ProviderPlayback/Sources/ProviderPlayback/PlaybackObserverStore.swift`
- Modify: `Packages/ProviderPlayback/Package.swift`
- Test: `Packages/ProviderPlayback/Tests/ProviderPlaybackTests.swift`

Define provider-owned playback state/mode/failure data, provider events, and a cancellable observer API without importing `MagicPlayMan` or an implementation plugin. Add tests for observer delivery and cancellation.

### Task 2: Move the concrete bridge into PluginPlayBack

**Files:**
- Modify: `Packages/PluginPlayBack/Sources/PluginPlayBack/Providers/PlaybackProvider.swift`
- Delete: `Packages/ProviderPlayback/Sources/ProviderPlayback/MagicPlayMan+PlaybackProviding.swift`
- Modify: `Packages/PluginPlayBack/Sources/PluginPlayBack/PluginPlayBack.swift`
- Test: `Packages/ProviderPlayback/Tests/ProviderPlaybackTests.swift`

Make `PlaybackProvider` translate `MagicPlayMan` events into provider events and send them through its own observer store. Keep all concrete-engine imports in PluginPlayBack.

### Task 3: Remove environment-object playback fallbacks

**Files:**
- Modify: `Packages/FactoryCisum/Sources/FactoryCisum/Views/KernelRootView.swift`
- Modify: `Packages/ProviderControlView/Sources/ProviderControlView/Views/ControlView.swift`
- Modify: `Packages/ProviderControlView/Sources/ProviderControlView/Views/Playing/StateView.swift`
- Modify: `Packages/ProviderControlView/Sources/ProviderControlView/Views/Playing/ProgressView.swift`
- Modify: `Packages/ProviderControlView/Package.swift`

Remove `MagicPlayMan` environment injection and all ProviderControlView fallback reads. Missing slots render empty content; playback-dependent UI must be supplied by plugins.

### Task 4: Repair plugin capability adapters and contributions

**Files:**
- Modify: `Packages/PluginPlaybackHero/Sources/Capabilities/PlaybackHeroPlaybackCapability.swift`
- Modify: `Packages/PluginPlaybackHero/Sources/PlaybackHeroPlugin.swift`
- Modify: `Packages/KernelCore/Sources/KernelCore/Contracts/SuperPlugin.swift`
- Modify: `Packages/KernelCore/Sources/KernelCore/Contracts/PluginProviding.swift`
- Modify: `Packages/KernelCore/Sources/KernelCore/Services/PluginContributionService.swift`
- Modify: `Packages/FactoryCisum/Sources/FactoryCisum/FactoryCisum.swift`

Remove `as? MagicPlayMan` from playback UI adapters. Add an explicit right-album contribution slot (or a neutral playback visual capability where required), and inject every playback-dependent slot from plugin contributions.

### Task 5: Enforce and verify the boundary

**Files:**
- Modify: `Scripts/check-plugin-boundaries.sh`
- Modify: `docs/architecture/plugin-boundaries.md`

Add static checks for `MagicPlayMan` environment objects and concrete casts in Provider/UI layers. Run focused package tests, boundary checks, and the application build if available.
