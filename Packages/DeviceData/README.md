# DeviceData

A tiny SwiftData model package that persists per-device usage metadata (device UUID, open timestamps, open counts, and hardware identification) for the Cisum app.

## Functional Logic

- **Core responsibility**: Define the `@Model`-annotated `DeviceData` SwiftData entity and its prebuilt fetch descriptor. The package itself contains no logic beyond the model; callers insert and query instances through a `ModelContainer`.

- **Key types**:
  - `DeviceData` (`Sources/DeviceData.swift`) — a `@Model` final class with a required `uuid` and mutable fields:
    - `firstOpenTime` / `lastOpenTime` (`Date`, default `.distantPast`)
    - `timesOpened` (`Int`, default `0`)
    - `audioCount` (`Int`, default `0`)
    - `name`, `model`, `os`, `version` (`String`, default `""`)
    - `init(uuid:)` sets only the UUID; all other properties keep their defaults.
  - `DeviceData.descriptorAll` — a shared `FetchDescriptor<DeviceData>` that matches every row and sorts by `firstOpenTime` ascending.

- **Workflow/data flow**: The host app creates a `ModelContainer` for `DeviceData`, inserts a single row on first launch, and updates `lastOpenTime` / `timesOpened` on each subsequent open. The descriptor is reused wherever the full device record list is needed.

- **Dependencies**: None. The package only imports `Foundation` and `SwiftData`; it exposes a library product named `CisumDeviceData`.

## Testing Logic

- **Test files**:
  - `Tests/DeviceDataTests.swift` — uses Swift Testing (`@Test` / `#expect`).
- **Key scenarios tested**:
  - `initSetsUuidAndDefaults` — the UUID is stored and all timestamp/count/string fields start at their documented defaults.
  - `propertiesAreMutable` — assigning to every property round-trips correctly (e.g. `firstOpenTime`, `timesOpened`, `audioCount`, `name`, `model`, `os`, `version`).
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/DeviceData
  swift test
  ```
