# CisumUIComponents

Shared UI foundation for Cisum: transparent re-exports of MagicKit and LumiUI, design-token access, responsive player layout metrics, a debug badge modifier, SF Symbol constants, gradient presets, and a small reusable progress bar.

## Functional Logic

- **Core responsibility**: Provide the cross-cutting UI building blocks that both the playback engine and the plugin layer depend on, so plugins do not each re-declare their own icon strings, gradients, shadows, or layout numbers.

- **Key types / extensions** (all under `Sources/CisumUIComponents/`):
  - `AppUI` (`Support/AppUICompat.swift`) — public typealias wrapper over LumiUI's internal `DesignTokens`, exposing `Typography`, `Spacing`, `Radius`, `Material`, `Duration`, and `Shadow` to Cisum modules.
  - `DebugBadgeModifier` + `View.debugBadge(_:color:alignment:)` (`Support/DebugBadge.swift`) — DEBUG-only overlay that stamps a colored badge and dashed border on a view; color is deterministically derived from the badge text. Compiled out in Release builds.
  - `Exports.swift` — `@_exported import LumiUI` and `@_exported import MagicKit`, so any consumer of `CisumUIComponents` sees those modules' public APIs without importing them separately.
  - `String` / `Image` icon constants (`Support/IconCompatibility.swift`) — a catalog of SF Symbol names (`cisumIconPlayFill`, `cisumIconShuffle`, `cisumIconHeart`, …), ready-made `Image` accessors, and the procedural `CoffeeReelIcon` (Cisum brand mark).
  - `CisumMagicBackground` (`Support/MagicBackgroundCompatibility.swift`) — named linear gradients: `sunset`, `aurora`, `deepOceanCurrent`, `deepForest`.
  - `MagicPlayManCompatibility.swift` — `MagicPlatformImage` (NSImage/UIImage typealias), `MagicThumbnailResult`, `MagicProgressBar` (a seekable `Slider` driven by `MagicProgressBarPolicy`), plus `View` helpers (`magicSize`, `magicBackground`, `infinite`, `inButtonWithAction`) and legacy icon/gradient constants.
  - `MagicUICompatibility.swift` — a large `View` extension bag: `cisumInfinite`, conditional `cisumIf`, `cisumButton`, `cisumPlaybackControl` (hover/press-scaling button style), `cisumShadow*`, `cisumRounded*`, `cisumCard`, `cisumCentered`, device-screen preview frames (`inIPhoneScreen`, `inIPadScreen`, `inIMacScreen`, `inDesktop`), and `CGSize` device constants.
  - `CisumPlayerLayout` (`Support/PlayerLayoutMetrics.swift`) — the responsive layout contract for the player window: minimum window size (400×250), control/content/album height thresholds, and functions `stateHeight(for:)`, `controlButtonHeight(width:height:)`, `shouldShowRightAlbum(width:)`, `needsExpandedWindow(for:)`.

- **Workflow/data flow**: Consumers `import CisumUIComponents` and immediately get MagicKit/LumiUI APIs plus the design tokens and layout constants. `CisumPlayerLayout` is the single source of truth the main window and player views use to decide whether to show the right-hand album column, how tall the state bar should be, and when the window needs to be expanded. `MagicProgressBarPolicy` centralizes seek/progress math so both the engine and the progress bar agree on clamping and formatting.

- **Dependencies** (from `Package.swift`):
  - `MagicKit` (local package).
  - `LumiUI` (remote, `from: "1.2.0"`).
  - The target also enables `StrictConcurrency=minimal`.

## Testing Logic

- **Test files**:
  - `Tests/ResponsiveLayoutPolicyTests.swift` — Swift Testing suite covering `CisumPlayerLayout` and `MagicProgressBarPolicy`.
- **Key scenarios tested**:
  - `playerLayoutMetricsRespectSizingThresholds` — verifies `defaultWindowSize`, the tiered `stateHeight(for:)` thresholds (24 / 36 / 48), `controlButtonHeight(width:height:)` clamping, `shouldShowRightAlbum(width:)` boundary at 768, and `needsExpandedWindow(for:)`.
  - `progressPolicyNormalizesInvalidAndOutOfRangeValues` — `MagicProgressBarPolicy` rejects NaN/infinity/negative durations and clamps current time to the valid range.
  - `seekPolicyClampsTrackCoordinatesAndRejectsInvalidGeometry` — x-coordinate-to-time ratio clamping, division-by-zero protection, and slider upper-bound fallback.
  - `formattedTimeIsNonnegativeAndUsesMinuteSecondFormat` — `mm:ss` formatting with negative/NaN safety.
  - `progressBarBindingClampsValuesAndReportsTheEffectiveSeekTime` — the normalized binding clamps writes and forwards the seek callback to the caller.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/CisumUIComponents
  swift test
  ```
