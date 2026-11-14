# ProviderAudioLike

Defines the `AudioLikeProviding` protocol and the cross-plugin `AudioLikeItem` DTO. SwiftData models, persistence and deduplication live in `PluginAudioLike`; this package only declares the call boundary.

## Functional Logic

- **Core responsibility**: read and mutate the liked-state of audio items without exposing SwiftData models across plugin boundaries.
- **Key types**:
  - `AudioLikeItem`: `Identifiable, Sendable, Equatable` DTO with `audioId: String`, `url: URL?`, `title: String?`, `liked: Bool`; `id` is `audioId`.
  - `AudioLikeProviding` (`@MainActor`, `AnyObject`, `Sendable`):
    - `func isLiked(url: URL) async -> Bool`
    - `func allLiked() async -> [AudioLikeItem]`
    - `func updateLikeStatus(audioId:url:title:liked:) async throws`
- **Provider pattern**: the kernel resolves a conforming implementation; consumers call async methods to query or toggle likes. No observer events are defined — consumers re-read state after mutations.
- **Dependencies**: none (Foundation only).

## Testing Logic

- **Test file**: `Tests/ProviderAudioLikeTests.swift`.
- **Key scenarios tested**:
  - `AudioLikeItem` exposes a stable transport identity (`id == audioId`) and preserves the `liked` flag.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderAudioLike
  swift test
  ```
- **Note**: provider package; the single test verifies the DTO's value semantics. Real like-state persistence is exercised in `PluginAudioLike`.
