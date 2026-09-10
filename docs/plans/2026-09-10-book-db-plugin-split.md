# Book DB Plugin Split Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Split audiobook database ownership from the audiobook database UI while keeping the existing library, import, settings, and playback behavior working.

**Architecture:** `PluginBookDBData` owns storage resolution, SwiftData container creation, the cached `BookRepo`, and the `BookDatabaseProviding` service. `PluginBookDB` becomes the View plugin and resolves that service through the Kernel. `ProviderBook` exposes the cross-plugin contract, DTOs, and events to consumers, while its separate `ProviderBookData` target contains the concrete database implementation. No View/Feature plugin may use the implementation target directly.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftData, SwiftUI, Cisum Kernel Provider registry, Swift Testing.

---

### Task 1: Add the data-layer Provider contract

**Files:**
- Modify: `Packages/ProviderBook/Sources/ProviderBook/BookProviding.swift`
- Test: `Packages/ProviderBook/Tests/ProviderBookTests.swift`

Add a `BookDatabaseProviding` protocol that exposes book DTO reads, imports, playback state, cover data, storage paths, and provider events without exposing Kernel or plugin lifecycle types.

Verify the protocol can be implemented by a lightweight test double and that the default unavailable behavior is safe.

### Task 2: Create `PluginBookDBData`

**Files:**
- Create: `Packages/PluginBookDBData/Package.swift`
- Create: `Packages/PluginBookDBData/Sources/BookDBDataPlugin.swift`
- Create: `Packages/PluginBookDBData/Sources/BookDatabaseProvider.swift`
- Create: `Packages/PluginBookDBData/README.md`

Move database-container/repository construction and caching into a new always-on plugin. Register and unregister `BookDatabaseProviding` during the plugin lifecycle, and invalidate the cache when storage changes or the plugin is disabled.

Verify the new package builds independently and its provider reports unavailable state before storage is configured.

### Task 3: Convert `PluginBookDB` into the View plugin

**Files:**
- Modify: `Packages/PluginBookDB/Sources/BookDBPlugin.swift`
- Modify: `Packages/PluginBookDB/Package.swift`
- Modify: `Packages/PluginBookDB/Sources/Views/BookDBDependencies.swift`
- Modify: `Packages/PluginBookDB/Sources/Views/BookDBViewDependencies.swift`

Remove storage and SwiftData construction from the View plugin. Resolve the data provider from the Kernel and use it for DTO reads, imports, playback state, cover data, disk, and database-root access. Keep all UI, ViewModel, playback, and scene responsibilities here.

Verify the View plugin still produces the tab and settings contribution when the data provider is present, and degrades to the existing unavailable view when absent.

### Task 4: Wire plugin registration and ordering

**Files:**
- Modify: `Packages/FactoryCisum/Package.swift`
- Modify: `Packages/FactoryCisum/Sources/FactoryCisum/PluginFactory.swift`

Add the new package to the factory and start the data plugin before the View plugin. Keep the existing `PluginBook` temporarily for compatibility while preventing `PluginBookDB` from being the second owner of its repository.

Verify the factory package resolves all products and the default plugin list contains both new roles.

### Task 5: Tests and migration checks

**Files:**
- Modify: `Packages/PluginBookDB/Tests/BookDBViewPluginTests.swift`
- Create or modify: `Packages/PluginBookDBData/Tests/BookDBDataPluginTests.swift`
- Modify: package README files as needed

Migrate the remaining feature observers from raw book database notifications to Provider events. Keep SwiftData-only persistence helpers in test targets. Add tests for provider registration, cache reuse, storage reset, and View-plugin fallback behavior. Run targeted package tests first, then the complete relevant package test set.

### Completed extraction step

The concrete `BookConfig` / `BookDB` / `BookRepo` / SwiftData model implementation now lives in the data-only `ProviderBookData` target. `ProviderBook` is limited to contracts, DTOs, events, constants, and errors. `PluginBookDBData` is the only production plugin importing `ProviderBookData`; View/Feature plugins resolve the contract through the Kernel instead.

---
