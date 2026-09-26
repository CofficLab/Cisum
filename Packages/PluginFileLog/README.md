# PluginFileLog

A system plugin that captures the app's `OSLog` entries to rotating on-disk log files for troubleshooting. It polls the process-local `OSLogStore`, writes timestamped log files under the app support directory, rotates by size, and purges old logs.

## Functional Logic

- **Core responsibility:** Mirror subsystem `com.yueyi.cisum` OSLog output into text files on disk, with automatic rotation and retention cleanup. Existing `os_log`/`Logger` call sites need no changes.
- **Key types:**
  - `FileLogPlugin` — `@MainActor final class` conforming to `AsyncSuperPlugin, SuperLog`. `id = "FileLogPlugin"`, `order = 1`, category `.system`, policy `.disabled`. Boots the coordinator, shuts it down on termination.
  - `FileLogPluginInfo` — enum holding `title`, `description`, `iconName = "doc.text.below.ecg"`.
  - `FileLogCoordinator` — `@unchecked Sendable` singleton that polls `OSLogStore` every 2 seconds, writes entries to the current `.log` file, rotates at 5 MB, and purges files older than 7 days.
  - `FileLogConfiguration` — protocol returning the log directory; `AppFileLogConfiguration` and `DefaultFileLogConfiguration` provide the default path (`Application Support/<bundleID>/db_<debug|production>_v<major>/FileLog/`).
  - `FileLogTerminationObserver` — macOS-only observer that stops the coordinator on `NSApplication.willTerminateNotification`.
  - Helpers: `FileLogRotation` (unique file naming, symlink-aware), `FileLogFileSizePolicy` (robust size extraction from file attributes).
  - Views: `FileLogPluginAboutView`, `FileLogPluginManualView`.
- **Plugin registration:** `onRegister` contributes About/Manual entries to `DocsViewProviding`. `onBootAsync` sets `FileLogCoordinator.shared.configuration = AppFileLogConfiguration()` and calls `start()`; on macOS it also starts `FileLogTerminationObserver`. `onShutdownAsync` stops the observer and coordinator.
- **Workflow/data flow:**
  1. App code logs via `OSLog`/`Logger` as usual.
  2. `FileLogCoordinator` opens a new dated log file (with a version/environment header) and polls `OSLogStore` from the last poll position.
  3. New entries matching the subsystem predicate are formatted (`[time] [level] [category] message`) and appended; the file is flushed periodically.
  4. When the file exceeds 5 MB, a new file is started; on startup, logs older than 7 days are deleted.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `ProviderDocsView`. Platforms: macOS 14+, iOS 17+. Resources: `Resources/Localizable.xcstrings`.

## Testing Logic

- **Test files:**
  - `Tests/FileLogPluginTests.swift` — covers configuration, rotation naming, size policy, the macOS termination observer, and the coordinator lifecycle.
- **Key scenarios tested:**
  - `DefaultFileLogConfiguration` resolves to a `FileLog` directory; rotation appends ` 2.log` when a timestamped file already exists, falls back to `Cisum Log.log` for an empty base name, and skips dangling symlink names.
  - `FileLogFileSizePolicy` reads `NSNumber`/`Int64`/`Int` attributes and clamps invalid (negative / oversized) values.
  - `FileLogTerminationObserver` (macOS) is idempotent on repeated `start`, fires the stop callback exactly once, and stops firing after `stopObserving`.
  - A serialized `FileLogCoordinatorLifecycleTests` suite verifies that `start` creates a `.log` file, repeated `start` is idempotent, and repeated `stop` is safe.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginFileLog
  swift test
  ```
- Tests focus on the pure helper logic (rotation, size policy, termination observer) and coordinator lifecycle; they do not assert on actual logged content.
