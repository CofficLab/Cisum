# PluginVideo

A small view library for browsing video files: a list/grid of video URLs with file-size labels, an open-in-Finder action, and accessibility support. It does not register a kernel plugin.

## Functional Logic

- **Core responsibility:** Render a list of video file URLs with per-row metadata (icon, file name, size) and an action to open the file. It is a reusable view layer consumed by other packages.
- **Key types:**
  - `VideoDB` — public container view that hosts `VideoGrid(files:)` and fills the available height.
  - `VideoGrid` — public list view; shows a `ContentUnavailableView` ("No video files available") when empty, otherwise a selectable list of `VideoTile`s.
  - `VideoTile` — public row showing a video icon, file title, asynchronously-loaded size, and an open button when the file exists.
  - Policies (internal, pure and testable):
    - `VideoFileSizeLoadPolicy.shouldApplySize(currentFile:requestedFile:)` — guards against applying a stale size after the row's file changes (symlink-aware via `isSameFileLocation`).
    - `VideoFileActionPolicy.canOpen(_:fileExists:)` — remote URLs always open; local URLs require the file to exist.
    - `VideoTileAccessibilityPolicy.selectionLabel(fileTitle:)` — `"Select <title>"`.
- **Plugin registration:** None. There is no `SuperPlugin` subclass.
- **Workflow/data flow:**
  1. Caller passes `[URL]` into `VideoDB`/`VideoGrid`.
  2. Each `VideoTile` loads its size in a background task (`Task.detached`, utility priority), guards cancellation and file identity before updating state, and shows "Calculating…"/"Unavailable" as appropriate.
- **Dependencies:** `CisumUIComponents`. Platforms: macOS 14+, iOS 17+. Resources: `Resources/Localizable.xcstrings`.

## Testing Logic

- **Test files:**
  - `Tests/VideoPluginTests.swift`.
- **Key scenarios tested:**
  - `VideoDB` and `VideoGrid` construct with files; empty-state title/description keys are `"Video"` / `"No video files available"`.
  - `shouldApplySize` accepts the same file, rejects a different current file, accepts a real/symlinked file pointing at the same location, and rejects results across two distinct dangling symlinks.
  - `canOpen` returns true for an existing local file and false for a missing one.
  - Accessibility selection label is `"Select Demo.mov"`.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginVideo
  swift test
  ```
- Tests target the pure load/open/accessibility policies (including real symlink behavior in /tmp); the actual list rendering is only smoke-tested via construction.
