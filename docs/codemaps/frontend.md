# Cisum Frontend Code Map

**Generated**: 2026-01-21
**Freshness**: Latest
**Scope**: SwiftUI views, UI components, and user interface

---

## UI Architecture Overview

Cisum uses **SwiftUI** for all user interface components with a plugin-based view composition system. The architecture supports both macOS and iOS with adaptive layouts.

### UI Framework Stack

- **SwiftUI** (Primary UI framework)
- **MagicUI** (Custom UI components)
- **AVKit** (Audio/video player views)
- **StoreKit** (Store views)

---

## View Hierarchy

### Root Structure

```
BootApp (App Entry)
└── Window/WindowGroup
    └── RootView
        └── ContentView (Main Container)
```

### Main View Structure

```
ContentView
├── ControlView (Top - Player Controls)
│   ├── HeroView (Album art)
│   ├── TitleView (Track info)
│   ├── OperationView (Playback controls)
│   └── ProgressView (Progress bar)
│
├── AppTabView (Middle - Content Area)
│   ├── Scene-based content
│   │   ├── AudioScene (Music Library)
│   │   └── BookScene (Book Library)
│   └── DBView (Database view)
│       ├── Duplicates
│       └── Navigation
│
└── StatusView (Bottom - Status Bar)
```

**Location**: `Core/Views/Layout/ContentView.swift`

---

## Plugin View Composition

### View Injection Points

Plugins inject UI at multiple levels:

```swift
SuperPlugin View Methods:
├── addRootView()       → Wraps entire app
├── addSceneItem()      → Provides main scenes
├── addSheetView()      → Modal sheets
├── addPosterView()     → Poster/promotional views
├── addTabView()        → Tab content
├── addSettingView()    → Settings entries
├── addStateView()      → State indicators
├── addStatusView()     → Status bar content
├── addGuideView()      → Onboarding views
└── addToolBarButtons() → Toolbar buttons
```

### View Wrapping Chain

```
User-Visible App =
  Plugin1 Root Wrap
    (Plugin2 Root Wrap
      (Plugin3 Root Wrap
        (ContentView)
      )
    )
```

**Example**:
- StoragePlugin might add storage selector
- WelcomePlugin might add onboarding overlay
- DebugPlugin might add debug controls

---

## Core UI Components

### Layout Views

**Location**: `Core/Views/Layout/`

| Component | Purpose |
|-----------|---------|
| `ContentView.swift` | Main app container |
| `SettingView.swift` | Settings page container |
| `Posters.swift` | Poster view compositor |
| `StatusView.swift` | Bottom status bar |

### Playing Views

**Location**: `Core/Views/Playing/`

| Component | Purpose |
|-----------|---------|
| `HeroView.swift` | Album art display |
| `TitleView.swift` | Track/book title |
| `OperationView.swift` | Playback controls (play/pause, next, prev) |
| `ProgressView.swift` | Progress bar |

### Common Views

**Location**: `Core/Views/Common/`

| Component | Purpose |
|-----------|---------|
| `LogoView.swift` | App logo component |

### Buttons

**Location**: `Core/Views/Buttons/`

| Component | Purpose |
|-----------|---------|
| `BtnToggleDB.swift` | Toggle database view visibility |

### Guide Views

**Location**: `Core/Views/GuideView/`

| Component | Purpose |
|-----------|---------|
| `Guide.swift` | Onboarding coordinator |
| `GuideDoneView.swift` | Completion screen |

### Database Views

**Location**: `Core/Views/DBView/`

| Component | Purpose |
|-----------|---------|
| `DBViewNavigation.swift` | Database navigation |
| `Duplicates.swift` | Duplicate file detector |

---

## Plugin-Specific UI

### Audio Plugin UI

**Scene Provider**: `AudioScenePlugin`

**Main Components**:
- Audio database view
- Audio player controls
- Progress tracking
- Like/favorite management
- Download management
- Settings integration

**Key Views**:
- `Plugins/Audio/Views/` (if present)
- Integrated via `AudioDBPlugin`

### Book Plugin UI

**Scene Provider**: `BookScenePlugin`

**Main Components**:
- Book database view
- Book player controls
- Reading progress
- Like/favorite management
- Settings integration

**Key Views**:
- `Plugins/Book/Views/` (if present)
- Integrated via `BookDBPlugin`

### Storage Plugin UI

**Location**: `Plugins/Storage/`

| Component | Purpose |
|-----------|---------|
| `StorageSettingView.swift` | Settings page |
| `FileInfo/FileInfoView.swift` | File details |
| `FileInfo/FileListView.swift` | File list |
| `FileInfo/FileIconView.swift` | File icon |
| `FileInfo/FileTitleView.swift` | File name |
| `FileInfo/FileSizeView.swift` | File size |
| `FileInfo/FileStatus.swift` | Download status |
| `FileInfo/FileItem.swift` | File data model |
| `FileInfo/FileExpandButton.swift` | Expand/collapse |
| `Migrate/MigrationProgressView.swift` | Migration progress |

### Store Plugin UI

**Location**: `Plugins/Store/Views/`

| Component | Purpose |
|-----------|---------|
| `StoreRootView.swift` | Store entry point |
| `PurchaseView.swift` | Purchase page |
| `AllSubscriptions.swift` | Subscription list |
| `StoreBtn.swift` | Store button |
| `RestoreView.swift` | Restore purchases |
| `StoreSettingEntry.swift` | Settings entry |
| `DebugView.swift` | Debug interface |
| `ProductCell.swift` | Product display |
| `ProductsSubscription.swift` | Subscription products |
| `MySubscription.swift` | User's subscription |
| `OneTimeView.swift` | One-time purchases |
| `NonRenewables.swift` | Non-renewable products |
| `ProductsOneTime.swift` | One-time product list |
| `ProductsNonRenewable.swift` | Non-renewable product list |
| `ProductsConsumable.swift` | Consumable products |
| `SubscriptionProductsView.swift` | Subscription product list |

### Welcome Plugin UI

**Location**: `Plugins/Welcome/`

| Component | Purpose |
|-----------|---------|
| `WelcomeView.swift` | Onboarding flow |
| `StorageView.swift` | Storage selection |

### Copy Plugin UI

**Location**: `Plugins/CopyPlugin/`

| Component | Purpose |
|-----------|---------|
| `BtnToggleCopying.swift` | Toggle copy status |
| `BtnDelTask.swift` | Delete copy task |

### Device Plugin UI

**Location**: `Plugins/DeviceData/`

| Component | Purpose |
|-----------|---------|
| `BtnDelDevice.swift` | Delete device button |

---

## Environment System

### Environment Values

**Location**: `Core/Environment/`

```swift
@Environment(\.demoMode) var isDemoMode
@Environment(\.showTabView) var showTabView
@Environment(\.tabViewVisibility) var tabViewVisibility
```

### Custom Environment Keys

**DemoMode** (`DemoMode.swift`):
- Controls demo mode behavior
- Affects UI and functionality

**TabViewVisibility** (`TabViewVisibility.swift`):
- Controls tab bar visibility
- Adaptive UI based on state

---

## UI State Management

### Provider-Based State

```swift
@StateObject var app = AppProvider()
@StateObject var p = PluginProvider()
```

**AppProvider State**:
- `showDB`: Database view visibility
- `demoMode`: Demo mode state
- Current scene tracking

**PluginProvider State**:
- `sceneNames`: Available scenes
- `currentSceneName`: Active scene
- Plugin registration state

### Combine Publishers

```swift
// Reactive updates
app.$showDB
  .sink { newValue in
    // Update UI
  }
```

---

## View Modifiers

### Plugin Wrappers

**Location**: Throughout plugin system

```swift
extension View {
  func inRootView() -> some View {
    // Apply plugin root view wrappers
  }
}
```

### Custom Modifiers

- `.inRootView()` - Apply plugin wrappers
- Platform-specific modifiers (macOS vs iOS)

---

## Platform-Specific UI

### macOS

**Window Configuration**:
```swift
Window("", id: "Cisum") {
  ContentView()
    .frame(minWidth: 350, minHeight: 250)
}
.windowToolbarStyle(.unifiedCompact(showsTitle: false))
.defaultSize(width: 350, height: 360)
```

**Unique Features**:
- Resizable window
- Toolbar integration
- Sidebar support

### iOS

**WindowGroup**:
```swift
WindowGroup {
  RootView {
    ContentView()
  }
}
```

**Unique Features**:
- Adaptive layout
- Home indicator handling
- Face ID / Touch ID integration

---

## Theming & Styling

### Color Scheme

**Location**: `Config.swift`

```swift
static var rootBackground: some View {
  MagicBackground.sunset.opacity(0.9)
}

static var getBackground: Color {
  #if os(macOS)
    Color(.controlBackgroundColor)
  #else
    Color(.systemBackground)
  #endif
}
```

### Custom Styles

**Store Button Style**:
- `Plugins/Store/Styles/BuyButtonStyle.swift`

### MagicUI Components

- `MagicButton`
- `MagicSettingSection`
- `MagicSettingRow`
- `MagicBackground`

---

## Responsive Design

### Adaptive Layouts

**Window-Based** (macOS):
```swift
.frame(minWidth: Config.minWidth, minHeight: Config.minHeight)
```

**Size-Based UI**:
- Control view height: `Config.controlViewMinHeight`
- Database view min height: `Config.databaseViewHeightMin`
- Album art threshold: `Config.minHeightToShowAlbum` (450pt)

### Scene Switching

```swift
// Dynamic content based on scene
switch currentSceneName {
case "音乐库":
  AudioSceneContent()
case "书籍库":
  BookSceneContent()
default:
  DefaultContent()
}
```

---

## Accessibility

### Platform Support

**macOS**:
- VoiceOver compatibility
- Keyboard navigation
- High contrast support

**iOS**:
- VoiceOver compatibility
- Dynamic Type support
- Touch accommodations

---

## Animations & Transitions

### SwiftUI Animations

```swift
.withAnimation {
  // State changes
}
```

### Transitions

- Scene transitions
- Sheet presentations
- Modal dismissals

---

## Localization

**Location**: `Localizable.xcstrings`

**Support**:
- Chinese (primary)
- English (secondary)

**Pattern**:
```swift
Text("localized_key", table: nil)
```

---

## UI Testing

### Xcode Previews

```swift
#Preview("App - Large") {
  ContentView()
    .inRootView()
    .frame(width: 600, height: 1000)
}
```

**Coverage**:
- Most views have previews
- Multiple size variants
- Platform-specific previews

### Debug Views

**Location**: `Core/Repo/`

| Component | Purpose |
|-----------|---------|
| `UserDefaultsDebugView.swift` | Inspect UserDefaults |
| `PluginRepoDebugView.swift` | Inspect plugin state |

---

## View Performance

### Optimization Strategies

1. **Lazy Loading**: Views loaded on demand
2. **View Modifiers**: Efficient composition
3. **State Isolation**: Minimal re-renders
4. **Plugin Caching**: Efficient plugin lookup

### Monitoring

- Instruments for profiling
- OSLog for performance logging
- Debug mode for development

---

## UI Component Taxonomy

### By Type

**Containers**:
- ContentView, RootView, AppTabView

**Controls**:
- Buttons, sliders, toggles

**Lists**:
- File lists, database views

**Posters**:
- Feature promotions

**Status**:
- Status bars, progress indicators

**Sheets**:
- Modal presentations

**Settings**:
- Setting pages, setting entries

### By Layer

**Core Layer**:
- Basic UI primitives
- Layout containers

**Plugin Layer**:
- Plugin-specific views
- Scene content

**System Layer**:
- Store, storage, settings
- Onboarding, debug

---

## UI Dependencies

```
Views
  ↓
Providers (State, App, Plugin)
  ↓
Events (NotificationCenter)
  ↓
Models (SwiftData)
```

---

## Future UI Enhancements

### Potential Improvements

1. **Animation System**: More sophisticated transitions
2. **Theme Support**: Dark/light mode customization
3. **Widget Support**: Home screen widgets (iOS)
4. **Gesture System**: Custom gestures for media control

---

## UI Metrics

- **Total View Files**: ~80+
- **Plugin Views**: 33+ plugins with UI
- **Core Views**: ~15 views
- **Platform Variants**: macOS, iOS
- **Preview Coverage**: ~70%

---

**End of Frontend Code Map**
