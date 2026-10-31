# Cisum

[![English](https://img.shields.io/badge/English-violet)](README.md) [![简体中文](https://img.shields.io/badge/中文文档-gray)](README-zh.md) [![Coffic](https://img.shields.io/badge/Coffic-green)](https://coffic.cn) [![Maintainer](https://img.shields.io/badge/Maintainer-blue)](https://github.com/nookery) [![AppStore](https://img.shields.io/badge/AppStore-red)](https://apps.apple.com/cn/app/cisum/id6466401036)

![Cisum for iPhone and Mac](./docs/readme-preview-en.svg)

## About

[Product Introduction](https://coffic.cn/cisum)

[App Store](https://apps.apple.com/cn/app/cisum/id6466401036)

## Motivation

Are you tired of being bothered by:

- Splash screen ads
- Shake-to-navigate features
- Endless pop-up windows
- 10-second launch times
- Overwhelming features

We decided to make our own app to keep software simple and pure.

## Architecture

Cisum is a plugin-based SwiftUI audio player. The codebase is split into independent
Swift packages under `Packages/`, grouped into four roles:

```text
FactoryCisum
  ├── Plugin*  ── consumes ──> Provider*
  ├── Provider* ── uses ─────> Kit*
  └── Kit*
```

| Role | Purpose |
|------|---------|
| `Kit*` | Reusable foundations not owned by one feature (playback primitives, UI components, event observation) |
| `Provider*` | App-facing contracts, domain models, events, observer handles |
| `Plugin*` | One feature each; consumes other features through Provider contracts |
| `FactoryCisum` | The single composition root that wires providers and plugins together |

Plugins never depend on each other directly — shared behavior travels through
`Provider*` (data and contracts) or `Kit*` (pure utilities) packages.

## Development

### Requirements

| Tool | Version |
|------|---------|
| macOS | 14.0 or later |
| Xcode | 27.2 or later |
| Swift | 6.0 or later |

### Build and run

```bash
git clone https://github.com/CofficLab/Cisum.git
cd Cisum

xcodebuild -list -project Cisum.xcodeproj
xcodebuild -project Cisum.xcodeproj -scheme Cisum -destination 'platform=macOS' build
```

### Build and test a single package

Every package is a standalone Swift package, which makes for a fast inner loop:

```bash
cd Packages/PluginAudioDBView
swift build
swift test
```

### Run the test suite

```bash
# Package-level unit tests
cd Packages && for p in Plugin*/; do [ -d "$p/Tests" ] || continue
  printf "%-26s " "$(basename $p)"; (cd $p && swift test 2>&1 | grep -E "✘|error:|Test run with" | tail -1)
done

# App-level unit and UI tests
xcodebuild -project Cisum.xcodeproj -scheme Cisum -destination 'platform=macOS' test
```

### Code coverage

```bash
scripts/collect-coverage.sh              # all packages with source code
scripts/collect-coverage.sh MagicKit     # one package
```

The report is written to `temp/coverage/report.md`.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the development
environment setup, architecture rules, coding conventions, localization and logging
guidelines, the commit message format, and the pull request workflow.

## Our Other Projects

- [macOS Network Control](https://coffic.cn/en/products/travelmode)
- [Git-based Project Management Tool](https://coffic.cn/en/products/gitok)
