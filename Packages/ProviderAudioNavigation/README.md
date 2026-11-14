# ProviderAudioNavigation

Defines the `AudioTrackNavigationProviding` protocol: the previous/next/first/last track navigation surface over the audio library. This package only declares the boundary; the actual data source and playback triggering live in the implementing plugin.

## Functional Logic

- **Core responsibility**: resolve the URL of the track adjacent to the current one in the library's playback order. Consumers then hand the returned URL to `PlaybackProviding` to actually play it.
- **Key protocol**: `AudioTrackNavigationProviding` (`@MainActor`, `AnyObject`):
  - `func nextURL(after current: URL?, verbose: Bool) async throws -> URL?`
  - `func previousURL(before current: URL?, verbose: Bool) async throws -> URL?`
  - `func firstURL() async throws -> URL?`
  - `func lastURL() async throws -> URL?`
  - Default extensions provide `nextURL(after:)` / `previousURL(before:)` that call through with `verbose: false`.
- **Provider pattern**: the kernel resolves a conforming implementation; the navigation plugin injects the concrete ordering source. Errors are thrown as `Error` by the implementation.
- **Dependencies**: none (Foundation only).

## Testing Logic

- **Test file**: `Tests/AudioTrackNavigationProvidingTests.swift`.
- **Key scenarios tested**:
  - A stub records the `verbose` flag it receives; the convenience overloads `nextURL(after:)` / `previousURL(before:)` forward with `verbose == false` and still return the configured next/previous URLs.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderAudioNavigation
  swift test
  ```
- **Note**: provider package; the test verifies the default convenience wrappers rather than real library ordering.
