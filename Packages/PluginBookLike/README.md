# PluginBookLike

The audiobook favorites (like/heart) plugin for Cisum. It persists which audiobooks
the user has liked, mirrors the player's like-toggle events into local storage, and
exposes a "Liked Books" settings pane listing all favorites.

## Functional Logic

- **Core responsibility:** maintain the liked-books set. While the audiobooks scene
  is active, it subscribes to playback like-status changes and saves them to
  `UserDefaults`; outside the scene it stays idle. It also renders the liked list.
- **Key types/protocols:**
  - `BookLikePlugin` — `AsyncSuperPlugin`, `SuperLog`; singleton `shared`,
    `id = "BookLikePlugin"`, `order = 6`, `iconName = "heart"`,
    `policy = .disabled`, `category = .feature`.
  - `BookLikePluginInfo` — title "Book Favorites", description "Manage book favorite
    status", `iconName = "heart"`, `order = 6`.
  - `BookLikeViewModel` — `ObservableObject`; `@Published` `likedBooks`, `isLoading`;
    scene-gated (`targetScene = .audiobooks`) save behavior; `reloadLikedBooks()`,
    `handleLikeStatusChanged(asset:liked:)`.
  - `BookLikeStore` — `enum` with `likedBooks(defaults:)`, `setLiked(_:url:defaults:)`,
    `removeAll(defaults:)`, `storedURL(from:)`; stores a `[url: title]` dictionary in
    `UserDefaults`, dedupes by same-file location.
  - `BookLikeItem` — `Identifiable`/`Hashable` (`url`, `title`).
  - `BookLikeObserver` — subscribes `.BookLikeStatusChanged` notifications, scene
    `.selectionChanged`, and playback `.likeStatusChanged(asset,isLiked:)` events.
  - `BookLikePlaybackCapability` protocol (`isAvailable`) +
    `BookLikePlaybackCapabilityAdapter`.
  - `BookLikeEvents` — `.BookLikeStatusChanged` notification name and
    `postBookLikeStatusChanged(url:liked:)` (dispatched on main thread).
  - `BookLikeSettingsView` — list of liked books (loading / empty / populated states).
  - `BookLikeRootView<Content>` / `BookLikePluginRootView` — passthrough root wrappers.
- **Plugin registration:** registered as `BookLikePlugin`. In `onRegister` it adds
  About/Manual docs. In `onBootAsync` it registers a settings navigation item
  (`id = "liked-books"`, destination `BookLikeSettingsView`); `addSettingView()`
  returns `nil`. `addRootView(content:)` wraps content. `onReadyAsync` / `onEnable`
  build the view model and observer; `onDisable` / `onShutdownAsync` tear them down
  and remove contributions.
- **Workflow/data flow:** entering the audiobooks scene activates like-saving. A
  player like toggle → playback `.likeStatusChanged` → `BookLikeObserver` →
  `BookLikeViewModel.handleLikeStatusChanged(asset:liked:)` (only when active and the
  playback capability is available) → `BookLikeStore.setLiked` +
  `.BookLikeStatusChanged` posted → view model reloads the list. Opening the settings
  pane loads favorites via the injected `BookLikeLoadProvider` closure.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `MagicPlayMan`,
  `CisumKernelSupport`, `ProviderDocsView`, `ProviderScene`, `ProviderPlayback`.

## Testing Logic

- **Test files:**
  - `Tests/BookLikePluginTests.swift` — metadata, settings item, notification
    delivery, store persistence, and view-model integration.
- **Key scenarios tested:**
  - Metadata: `iconName == "heart"`, `order == 6`.
  - Settings contribution: `addSettingView()` returns `nil`, navigation item has
    `id == "liked-books"` and title "Liked Books".
  - `.BookLikeStatusChanged` is delivered on the main thread when posted from a
    detached task.
  - `BookLikeStore`: add/remove persistence, title-sorted listing, symlinked books
    collapsing to one entry (and unliking via the real path clearing it), distinct
    dangling symlink books staying separate, and tolerance of empty/legacy/whitespace/
    invalid stored URL strings.
  - ViewModel integration via `BookLikeCapabilityProbe`: `handleAppear` loads items,
    like saves are gated by scene activation, activation requires an available
    capability, and like-status changes reload the list.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBookLike
  swift test
  ```
