# Contributing to Cisum

Thanks for your interest in improving Cisum. This document explains how to set up a
development environment, the conventions the codebase follows, and how to submit
changes.

Cisum is a plugin-based SwiftUI audio player for macOS and iOS. Most of the code lives
in independent Swift packages under `Packages/`, so contributions are usually scoped
to one package and can be built and tested independently.

---

## Table of Contents

- [Development Environment](#development-environment)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Architecture Rules](#architecture-rules)
- [Coding Conventions](#coding-conventions)
- [Localization](#localization)
- [Logging](#logging)
- [Commit Convention](#commit-convention)
- [Testing](#testing)
- [Submitting a Pull Request](#submitting-a-pull-request)
- [Reporting Bugs](#reporting-bugs)
- [Requesting Features](#requesting-features)
- [License](#license)

---

## Development Environment

### Requirements

| Tool | Version | Notes |
|------|---------|-------|
| macOS | 14.0 or later | iOS 17.0+ / macOS 14.0+ / visionOS 2.0+ |
| Xcode | 27.2 or later | Xcode 27.2 replaced `project.pbxproj` with the JSON `project.xcproj` format |
| Swift | 6.0 or later | Packages declare `swift-tools-version: 6.0`; the language mode is Swift 6 |
| Xcode Cloud | — | The `main` branch builds and publishes releases automatically |

Check your local toolchain:

```bash
xcodebuild -version   # Xcode 27.2, Build 27B52
swift --version       # Apple Swift version 6.x
```

### Signing

The app targets a real team (`Y6HZ9JJYV6`) and uses two iCloud containers:

| Build configuration | Bundle identifier | iCloud container | App group |
|---------------------|-------------------|------------------|-----------|
| Debug | `com.yueyi.cisum.debug` | `iCloud.yueyi.cisum.debug` | `group.com.yueyi.cisum.debug` |
| Release | `com.yueyi.cisum` | `iCloud.yueyi.cisum` | `group.com.yueyi.cisum` |

Debug builds use separate containers so a debug run never touches your real library.
If you do not have the team provisioned, change `DEVELOPMENT_TEAM` and the three
`CISUM_*_IDENTIFIER` settings in `Cisum.xcodeproj/project.xcproj` to your own values,
or run with automatic signing and a personal team.

Both configurations need the **iCloud (CloudDocuments + CloudKit)** and **App Groups**
capabilities enabled on the App ID.

---

## Getting Started

```bash
git clone https://github.com/CofficLab/Cisum.git
cd Cisum
```

### Build and run the app

```bash
# List the available schemes
xcodebuild -list -project Cisum.xcodeproj

# Build for macOS
xcodebuild -project Cisum.xcodeproj -scheme Cisum -destination 'platform=macOS' build

# Run the unit and UI test suites
xcodebuild -project Cisum.xcodeproj -scheme Cisum -destination 'platform=macOS' test
```

Two shared schemes are available:

- `Cisum` — the default scheme (Chinese-first UI).
- `Cisum-EN` — the same app with the English development region, useful for checking
  localization work.

### Build and test a single package

Every package under `Packages/` is a standalone Swift package. This is the fastest
inner loop for day-to-day work:

```bash
cd Packages/PluginAudioDBView
swift build
swift test
```

To run the same for every package that has tests:

```bash
cd Packages && for p in Plugin*/; do [ -d "$p/Tests" ] || continue
  printf "%-26s " "$(basename $p)"; (cd $p && swift test 2>&1 | grep -E "✘|error:|Test run with" | tail -1)
done
```

### Coverage

```bash
scripts/collect-coverage.sh              # all packages with source code
scripts/collect-coverage.sh MagicKit     # one package
```

The report is written to `temp/coverage/report.md`.

---

## Project Structure

```text
Cisum/
├── Cisum.xcodeproj/        # Xcode project (JSON project.xcproj format)
├── CisumApp/               # App entry points, Info.plist, app entitlements
├── CisumUITests/           # XCUITest end-to-end suite
├── CisumWidget/            # Widget sources (target currently disabled)
├── Packages/               # 59 local Swift packages — the bulk of the codebase
├── Shared/                 # Code shared with the widget extension
├── docs/                   # Architecture notes, code maps, plans
├── scripts/                # Coverage and store configuration helpers
└── .agent/rules/           # Project conventions enforced on every change
```

### Package roles

The package graph must stay within four roles:

```text
FactoryCisum
  ├── Plugin*  ── consumes ──> Provider*
  ├── Provider* ── uses ─────> Kit*
  └── Kit*
```

| Role | Purpose | Examples |
|------|---------|----------|
| `Kit*` | Reusable foundations not owned by one feature | `MagicKit`, `KitAppEvents`, `KitEventObservation` |
| `Provider*` | App-facing contracts, domain models, events, observer handles | `ProviderPlayback`, `ProviderStorage` |
| `Plugin*` | One feature each; consumes others via Provider contracts | `PluginAudioDBView`, `PluginAudioCopy` |
| `FactoryCisum` | The single composition root | `Packages/FactoryCisum` |

Three rules are absolute:

1. **Plugins never depend on each other.** Use a `Provider*` (for data and contracts)
   or `Kit*` (for pure utilities) package instead.
2. **`FactoryCisum` is the only assembly layer.** Features are wired together there,
   never inside a plugin.
3. **Providers stay pure.** A `Provider*` package declares protocols and data only —
   no SwiftData, SwiftUI, FileManager, or NotificationCenter plumbing.

### Layout inside a package

```text
Packages/<PackageName>/
├── Package.swift              # required
├── README.md                  # required
├── Sources/
│   └── <PackageName>/         # wrapper directory named after the package
│       ├── <Name>Plugin.swift # entry point
│       ├── Models/            # data models
│       ├── Views/             # SwiftUI views
│       ├── ViewModels/        # view models
│       ├── Observers/         # event subscriptions
│       ├── Capabilities/      # narrow contracts this package consumes
│       ├── Providers/         # contracts this package implements
│       └── Support/           # helpers
├── Tests/
│   └── <PackageName>Tests/    # wrapper directory named after the package
└── Resources/                 # optional, e.g. Localizable.xcstrings
```

Some newer packages use `path: "."` with `sources: ["Sources"]` instead of a wrapper
directory. Both layouts are acceptable — check the package's own `Package.swift` before
adding files. **If you add a new directory to a package that lists `sources:` explicitly,
add that directory to the list as well**, otherwise the files are silently not compiled.

---

## Architecture Rules

### Capabilities: narrow what you consume

A plugin should never hold `any SomeProviding` directly in a View, ViewModel, or
Observer. Instead, declare the exact members you need in a local capability protocol
and adapt the Provider to it:

```text
Sources/Capabilities/PlaybackSettingsSceneCapability.swift
```

```swift
@MainActor
protocol PlaybackSettingsSceneCapability: AnyObject {
    var currentScene: AppScene? { get }

    @discardableResult
    func addObserver(_ callback: @escaping (AppScene?) -> Void) -> any PlaybackSettingsSceneObserverHandle
}

@MainActor
final class PlaybackSettingsSceneCapabilityAdapter: PlaybackSettingsSceneCapability {
    private weak var scene: (any SceneProviding)?

    init(scene: (any SceneProviding)?) {
        self.scene = scene
    }

    var currentScene: AppScene? { scene?.currentScene }

    @discardableResult
    func addObserver(_ callback: @escaping (AppScene?) -> Void) -> any PlaybackSettingsSceneObserverHandle {
        // ...
    }
}
```

Rules that matter in practice:

- The capability protocol declares **only the members actually used**.
- Do **not** leak the Provider's `*ObserverHandle` type; define your own handle
  protocol inside the capability file.
- The Adapter holds the Provider with `weak`.
- **The plugin entry point must strongly retain the Adapter.** If the entry point
  creates an Adapter inline and injects it, the Adapter is released immediately and
  every capability silently becomes `nil`.
- If the Provider may register *after* your view is requested, hold a **lazy resolve
  closure** instead of a Provider snapshot:

  ```swift
  @MainActor
  final class XxxCapabilityAdapter: XxxCapability {
      private let resolve: @MainActor @Sendable () -> (any XxxProviding)?

      init(resolve: @escaping @MainActor @Sendable () -> (any XxxProviding)?) {
          self.resolve = resolve
      }

      private var provider: (any XxxProviding)? { resolve() }
  }
  ```

### Where to put shared code

| Need | Destination |
|------|-------------|
| A contract, model, or event shared by features | `Provider*` package |
| A reusable UI or pure utility | `Kit*` package |
| Behavior belonging to one feature | `Plugin*` package |
| App-only wiring | `FactoryCisum` |

Avoid capability adapters that merely mirror an entire Provider protocol — that adds
indirection without narrowing, which is the actual defect the pattern exists to prevent.

---

## Coding Conventions

### SwiftUI

- Follow `.claude/SWIFTUI_GUIDE.md` and the `swiftui-standards` skill.
- Use the `@Observable` macro where possible; prefer `@Observable` over
  `ObservableObject` for new types.
- Group code with `// MARK:` sections.
- Provide a `#Preview` for every view.
- Keep views free of business logic; move it into a ViewModel.

### General Swift

- The language mode is Swift 6 with strict concurrency. Code must compile without
  concurrency warnings.
- Prefer `async`/`await` and actors over `DispatchQueue`. Avoid adding new
  `DispatchQueue.main` usage; migrate touched call sites when practical.
- Use `os.Logger` via the `SuperLog` protocol for logging (see [Logging](#logging)).
- Never use `print()` for logging in production code.

### Swift Package Manager

- Packages declare `swift-tools-version: 6.0` (`MagicPlayMan` is still on 5.9) and use
  the Swift 6 language mode.
- Platforms are `.macOS(.v14)` and `.iOS(.v17)`.
- Packages that ship resources declare `defaultLocalization: "en"`. The four
  resource-free packages (`KitAppEvents`, `KitAudioRepositoryImport`,
  `KitEventObservation`, `ProviderSettingsHost`) omit it.
- Local dependencies use `.package(path: "../OtherPackage")`; shared packages use
  `.package(url: "https://github.com/CofficLab/...", from: "x.y.z")`.

---

## Localization

Every user-visible string must be localized. Each package owns its own string
catalog.

### Where catalogs live

All 50 catalogs currently live in the package's **root** `Resources/` directory:

```text
Packages/<PackageName>/Resources/Localizable.xcstrings
```

The `Package.swift` declares it in one of two equivalent forms:

```swift
resources: [.process("Resources")]                              // whole directory
resources: [.process("Resources/Localizable.xcstrings")]        // single file
```

If you add a catalog to a package that lists `sources:` explicitly, make sure the
`Resources` directory is still reachable — otherwise the file is silently not bundled
and `bundle: .module` lookups fall back to the raw key.

### Using a string

```swift
// ✅ Correct — bundle: .module is mandatory
Text(String(localized: "Add", bundle: .module))

// ❌ Wrong — the translation will not be found
Text(String(localized: "Add"))
```

With arguments:

```swift
String(localized: "Only %lld files were added because the free file limit is almost full",
         bundle: .module, arguments: count)
```

### Adding a language

1. Add the key with an English source value to the package's `.xcstrings`.
2. Add `zh-Hans` (Simplified Chinese) and `zh-HK` (Traditional Chinese) entries.
3. Keep the source language English — never use Chinese as the key.
4. If the package lists `sources:` explicitly, confirm the `Resources` directory is
   included in `resources: [.process("Resources")]` or
   `.process("Resources/Localizable.xcstrings")`.

---

## Logging

The project uses `SuperLog` (`Packages/MagicKit/Sources/Protocols/SuperLog.swift`),
which produces a consistent prefix:

```text
[UI] | 📦 AudioDB | 消息内容
```

The prefix carries the thread QoS, a type emoji, and the type name.

```swift
final class SomeService: SuperLog {
    nonisolated static let emoji = "📦"
    nonisolated static let verbose = false

    func doSomething() {
        os_log("\(self.t)开始处理")
    }
}
```

Guidelines:

- Always include the `self.t` (instance) or `Self.t` (static) prefix.
- Use `os_log` / `os.Logger`, never `print`.
- Gate verbose logging behind `if Self.verbose { ... }`.
- Detailed conventions: `docs/superlog-logging-convention.md`.

---

## Commit Convention

The project follows a strict commit message format:

```text
<type>(<scope>): <description>
```

- `type` and `description` are **required** and written in **English**.
- `scope` is optional but recommended — use the package or component name.
- `description` starts lowercase, uses the imperative mood, and has **no trailing period**.

### Types

| Type | Use |
|------|-----|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Refactor without behavior change |
| `style` | Formatting only |
| `perf` | Performance improvement |
| `chore` | Dependencies, build scripts, housekeeping |
| `docs` | Documentation |
| `test` | Tests |

### Scopes

Use the package or component name: `PluginAudioDBView`, `ProviderPlayback`,
`FactoryCisum`, `MagicKit`, `CisumUITests`.

### Examples

```text
feat(PluginAudioDBData): add capacity gate and sync fallback
fix(MagicKit): harden JSON int parsing and markdown blank-line collapsing
refactor(FactoryCisum): assemble the root view before it first appears
chore: update Package.resolved and add screen recorder plugin plan
```

Keep one commit to one concern. Split unrelated changes, and separate refactors from
new features.

---

## Testing

### Test frameworks

New tests use **Swift Testing**:

```swift
import Testing
@testable import PluginAudioDBView

@Test func audioListLoadsMoreFromCurrentLoadedCount() {
    #expect(AudioListLoadPolicy.nextLoadOffset(loadedCount: 90, currentPage: 0, pageSize: 50) == 90)
}
```

A suite-based variant is used when several tests share a fixture:

```swift
@Suite("列表项文件大小缓存")
struct AudioItemFileSizeCacheTests {
    @Test("returns a cached size for the same URL")
    func returnsCachedSize() {
        #expect(cache.size(for: url) == expected)
    }
}
```

Legacy XCTest suites may remain; they do not need to be migrated.

### What to test

- Unit tests live in the package's own `Tests/` directory.
- Keep policy and decision logic in testable, non-UI types so it can be asserted
  directly — the codebase already does this with types like `AudioListLoadPolicy`.
- Add a UI test in `CisumUITests/` for end-to-end user flows (launch, playback,
  library, iCloud download, copy, storage location, store, settings navigation).

### Running tests

```bash
# One package
cd Packages/PluginAudioDBView && swift test

# Every package with tests
cd Packages && for p in Plugin*/; do [ -d "$p/Tests" ] || continue
  printf "%-26s " "$(basename $p)"; (cd $p && swift test 2>&1 | grep -E "✘|error:|Test run with" | tail -1)
done

# Full app suite including UI tests
xcodebuild -project Cisum.xcodeproj -scheme Cisum -destination 'platform=macOS' test
```

### Boundary self-check

Before delivering a change that adds or modifies a plugin package, run the boundary
scans described in `.agent/skills/plugin-boundaries/SKILL.md`. They check for
plugin-to-plugin imports, implicit environment injection, and View/ViewModel code
holding a wide `any *Providing` provider.

---

## Submitting a Pull Request

1. **Branch from `dev`.** The `main` branch is reserved for releases.
   ```bash
   git checkout dev
   git pull
   git checkout -b feature/short-description
   ```
2. **Make focused changes.** One concern per commit, following the commit convention.
3. **Run the checks.**
   ```bash
   cd Packages/<YourPackage> && swift test
   xcodebuild -project Cisum.xcodeproj -scheme Cisum -destination 'platform=macOS' build
   ```
4. **Run the boundary scan** if you touched package dependencies.
5. **Write a clear PR description**: what changed, why, and how it was verified.
6. **Open the PR against `dev`.**
   ```bash
   git push -u origin feature/short-description
   ```
7. Keep the PR open for review. The maintainer may ask for changes or squash the
   commits.

### Commit signing

CI signs release tags. Individual commits do not need to be signed.

---

## Reporting Bugs

Open an issue at [CofficLab/Cisum/issues](https://github.com/CofficLab/Cisum/issues)
and include:

- **What you did** — the steps to reproduce.
- **What you expected** — the behavior you think should happen.
- **What actually happened** — including the exact error message.
- **Environment** — macOS version, Xcode version, and whether the problem also occurs
  in the Debug build.
- **Screenshots or logs** when they help.

Log output can be filtered by subsystem:

```bash
log stream --predicate 'subsystem == "com.coffic.cisum"'
log stream --predicate 'subsystem == "com.coffic.cisum" AND category == "plugin.audio-db-view"'
```

Please search existing issues first — the repository has closed many duplicates already.

---

## Requesting Features

Open an issue describing the user-facing problem, not just the implementation you
have in mind. Include:

- The workflow you are trying to complete.
- Why the current behavior does not support it.
- Any alternatives you have considered.

Feature work that crosses package boundaries usually needs a design note first; the
existing notes in `docs/plans/` are a good reference.

---

## License

Cisum is released under the [Apache License 2.0](LICENSE). By contributing, you agree
that your contributions are licensed under the same terms.
