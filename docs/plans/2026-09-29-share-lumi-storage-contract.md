# Share Lumi Storage Contract Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let Cisum expose its existing storage service through Lumi's shared storage contract while preserving Cisum's storage-location features.

**Architecture:** Keep one `StorageProvider` instance as the source of truth. It will continue conforming to Cisum's extended storage protocol and will also conform to Lumi's `ProviderStorage.StorageProviding` protocol, mapping `databaseRoot` to Lumi's `dataRootDirectory` and sharing plugin/Core directories. The Cisum storage plugin will register the same instance under both protocol identities; no second storage service or second data root will be introduced.

**Tech Stack:** Swift 6, Swift Package Manager, KernelCore, LumiProviders `ProviderStorage`, Cisum `CisumProviderStorage`, Swift Testing.

---

### Task 1: Add Lumi storage protocol dependency

**Files:**
- Modify: `Packages/PluginStorage/Package.swift`

**Steps:**
1. Add the remote `ProviderStorage` product from `LumiProviders` to the `PluginStorage` target and test target.
2. Keep the local `CisumProviderStorage` dependency unchanged for storage-location APIs.
3. Resolve the package and verify both ProviderStorage modules are available to the target.

### Task 2: Make Cisum's provider satisfy both contracts

**Files:**
- Modify: `Packages/PluginStorage/Sources/Providers/StorageProvider.swift`

**Steps:**
1. Keep the existing Cisum storage-location implementation intact.
2. Add conformance to Lumi's `ProviderStorage.StorageProviding` protocol.
3. Map `dataRootDirectory` to `databaseRoot`.
4. Implement Lumi's `coreDataDirectory()` using `<databaseRoot>/Core/`.
5. Rely on Lumi's default implementations for version-root discovery and directory-size calculation.

### Task 3: Register one instance under both protocol identities

**Files:**
- Modify: `Packages/PluginStorage/Sources/StoragePlugin.swift`

**Steps:**
1. Construct one `StorageProvider` instance in `onBootAsync`.
2. Register that instance as Cisum's storage protocol.
3. Register the same instance as Lumi's shared storage protocol.
4. Preserve settings ViewModel binding and shutdown behavior.

### Task 4: Add compatibility regression tests

**Files:**
- Modify: `Packages/PluginStorage/Tests/StoragePluginTests.swift`

**Steps:**
1. Assert that one `StorageProvider` can be resolved through both protocol types.
2. Assert both protocol views return the same root and plugin directory.
3. Assert the Lumi Core directory is created under Cisum's database root.
4. Run the focused `PluginStorage` test suite.

### Task 5: Verify Factory integration

**Files:**
- No source changes expected unless compilation exposes a dependency-order issue.

**Steps:**
1. Run `swift test` for `Packages/PluginStorage`.
2. Run `swift test` for `Packages/FactoryCisum`.
3. Confirm no duplicate Provider registration or changed Cisum storage-setting behavior.

## Implementation result

- `StorageProvider` now conforms to both `CisumProviderStorage.StorageProviding` and Lumi's `ProviderStorage.StorageProviding`.
- `StoragePlugin` registers one concrete provider instance under both protocol identities, so both views share the same data root.
- Cisum's storage-location, iCloud/local selection, settings UI, and observer behavior remain unchanged.
- `PluginStorage` tests pass with 59 tests; `FactoryCisum` tests pass with 6 tests.

## Consumer migration result

The first generic consumers now resolve Lumi's storage contract directly:

- `PluginPluginManager` uses `ProviderStorage.StorageProviding.pluginDataDirectory(for:)`.
- `PluginScene` uses the same Lumi contract for scene persistence.
- `PluginPlayBack` uses `dataRootDirectory` for playback-state persistence; the existing `PluginPlayBack/current-playback.plist` layout is unchanged.
- `FactoryCisum` debug commands use `dataRootDirectory` when opening the app database directory.

Cisum-specific consumers that need storage-location, iCloud, database-file, or observer APIs remain on `CisumProviderStorage.StorageProviding` by design.

Focused verification passed:

- `PluginPluginManager`: 25 tests.
- `PluginScene`: 18 tests.
- `PluginPlayBack`: 11 tests.
- `FactoryCisum`: 6 tests.
