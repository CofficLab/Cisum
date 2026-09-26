# PluginDevice

A SwiftData data layer for Cisum that tracks the devices (installations) that share an iCloud-synced library. It provides an actor-isolated `ModelActor` (`DBSynced`) plus `DeviceData` CRUD extensions and a delete-device button view.

## Functional Logic

- **Core responsibility:** Persist and query `DeviceData` records (one per device/installation) through a serialized SwiftData context, recording open times, audio counts, and device metadata. This package is a data/service library — it does not register a plugin with the kernel.
- **Key types:**
  - `DBSynced` — an `actor` conforming to `ModelActor`, `ObservableObject`, and `SuperLog`. Wraps a `ModelContainer`, disables autosave, and exposes generic insert / delete / save / fetch / count / paginate APIs plus a `printRunTime(_:tolerance:_:)` timing helper.
  - `DBSynced (DeviceDataExt)` — extensions adding `insertDeviceData(deviceId:)`, `saveDeviceData(uuid:audioCount:)`, `deleteDevice(_:)`, `find(_:)`, and `allDevices()`.
  - `BtnDelDevice` — a SwiftUI view for deleting a `DeviceData` (the button body is currently commented out; it is a placeholder).
- **Plugin registration:** None. There is no `SuperPlugin` subclass in this package; it is consumed by other packages.
- **Workflow/data flow:**
  1. A caller builds an in-memory or on-disk `ModelContainer` with the `DeviceData` schema and constructs `DBSynced(container)`.
  2. `insertDeviceData` records a new device with name/model/OS/version captured from `MagicApp`.
  3. `saveDeviceData` increments `timesOpened`, updates `lastOpenTime`/`audioCount`, and inserts the record on first sight.
  4. Queries (`find`, `allDevices`, `get`, `getCount`) run against the actor-isolated `ModelContext`.
- **Dependencies:** `DeviceData` (product `CisumDeviceData`) and `CisumUIComponents`. Platforms: macOS 14+, iOS 17+. Resources: `Resources/Localizable.xcstrings`.

## Testing Logic

- **Test files:**
  - `Tests/DevicePluginTests.swift` — exercises `DBSynced` end-to-end against an in-memory `ModelContainer`.
- **Key scenarios tested:**
  - `DBSynced.emoji` metadata export.
  - Insert/fetch-all/count ordering; predicate-based `getCount`/`get`.
  - `destroy(for:)` deletes all records of a model; `save(completion:)` reports errors.
  - `insertDeviceDataPersistsRecord`, `saveDeviceDataIncrementsTimesOpened` (incrementing `timesOpened` and `audioCount` across calls), `saveDeviceDataInsertsWhenMissing`.
  - `deleteDeviceRemovesRecord`, `allDevicesReturnsRecords` ordering, and `printRunTimeRunsClosure`.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginDevice
  swift test
  ```
- Test coverage is substantive: it validates the real SwiftData CRUD behavior rather than only plugin identity.
