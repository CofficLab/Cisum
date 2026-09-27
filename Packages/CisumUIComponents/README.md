# KitUIComponents (module `CisumUIComponents`)

Shared Cisum UI kit: responsive layout metrics, debug badge presentation, SF Symbol constants, reusable view modifiers, and the Cisum brand icon.

## Functional Logic

- **Core responsibility**: Provide Cisum-owned visual building blocks. Playback-specific controls and policies live in `KitPlayback`, not in this general UI kit.

- **Key types / extensions** (all under `Sources/CisumUIComponents/`):
  - `DebugBadgeModifier` + `View.debugBadge(_:color:alignment:)` (`Support/DebugBadge.swift`) — DEBUG-only overlay that stamps a colored badge and dashed border on a view; color is deterministically derived from the badge text. Compiled out in Release builds.
  - `LumiUI` and `MagicKit` are not re-exported; each consumer imports and declares the modules it uses directly.
  - `String` / `Image` Cisum icon catalog (`Support/CisumIcons.swift`) — SF Symbol names (`cisumIconPlayFill`, `cisumIconShuffle`, `cisumIconHeart`, …), ready-made `Image` accessors, and the procedural `CoffeeReelIcon` brand mark.
  - `CisumViewModifiers.swift` — Cisum-owned view utilities: conditional rendering, playback button styling, shadows, rounded shapes, cards, centering, and device preview frames.
  - `CisumPlayerLayout` (`Support/PlayerLayoutMetrics.swift`) — the responsive layout contract for the player window: minimum window size (400×250), control/content/album height thresholds, and functions `stateHeight(for:)`, `controlButtonHeight(width:height:)`, `shouldShowRightAlbum(width:)`, `needsExpandedWindow(for:)`.

- **Workflow/data flow**: Consumers use Cisum-owned UI components and metrics from this kit. `CisumPlayerLayout` is the single source of truth for the main window and player views' album-column, state-bar, and minimum-size decisions. The seek control and its policy are owned and tested by `KitPlayback`.

- **Dependencies** (from `Package.swift`):
  - `LumiUI` (remote, exact version `1.4.0`).
  - The target also enables `StrictConcurrency=minimal`.

## Testing Logic

- **Test files**:
  - `Tests/ResponsiveLayoutPolicyTests.swift` — Swift Testing suite covering `CisumPlayerLayout` thresholds.
- **Key scenarios tested**:
  - `playerLayoutMetricsRespectSizingThresholds` — verifies `defaultWindowSize`, the tiered `stateHeight(for:)` thresholds (24 / 36 / 48), `controlButtonHeight(width:height:)` clamping, `shouldShowRightAlbum(width:)` boundary at 768, and `needsExpandedWindow(for:)`.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/CisumUIComponents
  swift test
  ```
