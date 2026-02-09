# Cisum Architecture Code Map

**Generated**: 2026-01-21
**Freshness**: Latest
**Scope**: High-level system architecture

---

## System Overview

Cisum is a plugin-based SwiftUI audio player application for macOS and iOS. The architecture follows a modular design with strong separation of concerns.

### Technology Stack

**Frameworks**:
- SwiftUI (UI)
- SwiftData (Persistence)
- Combine (Reactive Programming)
- AVKit (Audio/Video Playback)
- StoreKit (In-App Purchases)

**External Libraries**:
- MagicKit 1.2.7 (Core utilities)
- MagicPlayMan (Playback management)
- MagicUI (UI components)
- MagicAlert (Alert system)
- MagicDevice (Device utilities)
- ZIPFoundation (File compression)

---

## Core Architecture

### Application Bootstrap

```
BootApp (Entry Point)
├── StoreService.bootstrap()
├── AppDelegate (Platform-specific lifecycle)
└── RootView
    └── ContentView
```

**Key Files**:
- `Core/Bootstrap/BootApp.swift`
- `Core/Bootstrap/AppDelegate.swift`
- `Core/Bootstrap/Config.swift`

### Provider Layer

Centralized state and service management:

```
StateProvider
├── Application state messages
└── Logging coordination

CloudProvider
├── iCloud account status
└── Cloud service coordination

AppProvider
├── UI state management
├── Demo mode
└── Database view visibility

PluginProvider
├── Plugin registration
├── Scene management
└── View composition
```

**Location**: `Core/Providers/`

### Event System

Decoupled communication via NotificationCenter:

```
AppEvents        → Application lifecycle
BookEvents       → Book database operations
AudioLikeEvents  → Audio like status
CloudEvents      → iCloud state changes
StorageEvents    → Storage location updates
ConfigEvents     → Configuration changes
```

**Location**: `Core/Events/`

**Pattern**:
```swift
// Posting
NotificationCenter.post(.bookDBUpdated)

// Listening
View.onBookDBUpdated { _ in ... }
```

---

## Plugin System

### Architecture Pattern

**Protocol-Based Plugin Architecture**:
- All plugins conform to `SuperPlugin` (Actor)
- Auto-discovery via Objective-C runtime
- Order-based execution system
- Dynamic view composition

### Plugin Protocol Contract

```swift
protocol SuperPlugin: Actor {
    // Identity
    var id: String { get }
    var label: String { get }
    var title: String { get }
    var description: String { get }
    var iconName: String { get }

    // Scene Provision
    @MainActor func addSceneItem() -> String?

    // View Injection
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView?
    @MainActor func addSheetView(storage: StorageLocation?) -> AnyView?
    @MainActor func addPosterView() -> AnyView?
    @MainActor func addSettingView() -> AnyView?
    @MainActor func addToolBarButtons() -> [(id: String, view: AnyView)]

    // Execution Control
    static var order: Int { get }
    static var shouldRegister: Bool { get }
}
```

### Plugin Categories

#### 1. Audio Plugins (11 plugins)
**Execution Order**: 0-9999

| Plugin | Order | Responsibility |
|--------|-------|----------------|
| AudioScenePlugin | 0 | Provides "音乐库" scene |
| AudioPlugin | 1 | Core audio functionality |
| AudioDBPlugin | - | Database view integration |
| AudioProgressPlugin | - | Playback progress tracking |
| AudioPosterPlugin | - | Poster view |
| AudioLikePlugin | - | Like/favorite management |
| AudioPlayModePlugin | - | Play mode controls |
| AudioControlPlugin | - | Playback controls |
| AudioDownloadPlugin | - | Download management |
| AudioJobPlugin | - | Background jobs |
| AudioSettingsPlugin | - | Settings integration |

#### 2. Book Plugins (9 plugins)

| Plugin | Order | Responsibility |
|--------|-------|----------------|
| BookScenePlugin | - | Provides "书籍库" scene |
| BookPlugin | - | Core book functionality |
| BookDBPlugin | - | Database view integration |
| BookProgressPlugin | - | Reading progress |
| BookPosterPlugin | - | Poster view |
| BookLikePlugin | - | Like/favorite management |
| BookPlayModePlugin | - | Play mode controls |
| BookControlPlugin | - | Playback controls |
| BookSettingsPlugin | - | Settings integration |

#### 3. System Plugins (9 plugins)

| Plugin | Order | Responsibility |
|--------|-------|----------------|
| StoragePlugin | 10 | Storage location management |
| CopyPlugin | - | Copy task management |
| ResetPlugin | - | Data reset functionality |
| WelcomePlugin | - | Onboarding flow |
| VersionPlugin | - | Version information |
| DebugPlugin | - | Debug tools |
| OpenButtonPlugin | - | File opening |
| LikeButtonPlugin | - | Like button component |
| StorePlugin | 80 | In-app purchases |

### Plugin Execution Flow

```
1. PluginProvider Discovery
   ↓
2. Sort by order property
   ↓
3. Register plugins (if shouldRegister = true)
   ↓
4. Collect scenes from addSceneItem()
   ↓
5. Compose views via addRootView() wrapping
   ↓
6. Inject UI elements (sheets, posters, toolbars)
```

### View Wrapping Pattern

Plugins wrap views in a chain:

```swift
Plugin1(
  Plugin2(
    Plugin3(
      OriginalContent
    )
  )
)
```

---

## Data Layer

### Persistence Strategy

**SwiftData Models**:
- `AudioModel` (music files)
- `BookModel` (e-books)
- `CopyTask` (copy operations)

**Storage Locations**:
- iCloud Documents
- Local Documents
- Custom locations

### Repository Pattern

```
AudioRepo      → Audio data access
BookRepo       → Book data access
UIRepo         → UI state persistence
PluginRepo     → Plugin configuration
AudioConfigRepo → Audio settings
BookSettingRepo → Book settings
```

**Location**: `Plugins/{Category}/Repo/`

### Data Transfer Objects (DTOs)

**Store**:
- `ProductDTO`
- `SubscriptionDTO`
- `SubscriptionGroupDTO`
- `ProductGroupsDTO`

**Book**:
- `BookDTO`
- `BookModelExt+DTO`

**Storage**:
- `FileItem`
- `FileStatus`

---

## UI Architecture

### View Hierarchy

```
ContentView (Root)
├── ControlView (Top - Player controls)
├── AppTabView (Middle - Content area)
│   └── Scene-based content
│       ├── AudioScene
│       └── BookScene
└── StatusView (Bottom - Status bar)
```

### Scene Management

**Dynamic Scenes**:
- Plugins provide scenes via `addSceneItem()`
- Last active scene persisted and restored
- Seamless scene switching

**Available Scenes**:
- 音乐库 (Music Library)
- 书籍库 (Book Library)

### Environment Values

```swift
@Environment(\.demoMode) var isDemoMode
@Environment(\.showTabView) var showTabView
@Environment(\.tabViewVisibility) var tabViewVisibility
```

---

## Key Architectural Decisions

### 1. Plugin-Based Modularity
- **Rationale**: Easy feature addition without core changes
- **Trade-off**: Increased complexity in view composition

### 2. Actor-Based Concurrency
- **Rationale**: Thread-safe plugin system
- **Benefit**: Eliminates data races in plugin execution

### 3. Event-Driven Communication
- **Rationale**: Decoupled component interaction
- **Pattern**: NotificationCenter + Combine publishers

### 4. Protocol-Oriented Design
- **Rationale**: Loose coupling between components
- **Benefit**: Easy testing and mock implementations

### 5. Scene-Based Navigation
- **Rationale**: Flexible content switching
- **Benefit**: Plugins can provide main content areas

---

## Module Dependencies

```
BootApp
  ↓
Core Framework
  ├── Providers (State, Cloud, App, Plugin)
  ├── Events (NotificationCenter)
  ├── Bootstrap (Config, AppDelegate)
  └── Contract (SuperPlugin)
  ↓
Plugin System (33 plugins)
  ├── Audio Plugins
  ├── Book Plugins
  └── System Plugins
  ↓
Data Layer
  ├── SwiftData Models
  ├── Repositories
  └── DTOs
  ↓
External Services
  ├── iCloud (CloudKit)
  ├── StoreKit (IAP)
  └── AVFoundation (Playback)
```

---

## Cross-Platform Support

### Conditional Compilation

```swift
#if os(macOS)
    // macOS-specific code
    @NSApplicationDelegateAdaptor var appDelegate
#elseif os(iOS)
    // iOS-specific code
    @UIApplicationDelegateAdaptor var appDelegate
#endif
```

**Platform Differences**:
- macOS: Single window, resizable
- iOS: WindowGroup, adaptive layout

### Shared Core Logic

Maximum code reuse across platforms through:
- Common Core framework
- Shared plugin system
- Platform-specific UI only when necessary

---

## Performance Considerations

### Optimizations

1. **Lazy Loading**: Plugins loaded on demand
2. **Actor Isolation**: Prevents concurrent access issues
3. **Memory Management**: Proper cleanup in providers
4. **View Modifiers**: Efficient view composition

### Monitoring

- OSLog for system-level logging
- Debug mode for development
- Performance profiling via Instruments

---

## Security Considerations

### Data Protection

- iCloud data encrypted
- Local sandbox access only
- No hardcoded credentials
- StoreKit receipt validation

### Permissions

- File access (user-granted)
- iCloud (user-controlled)
- Network (audio downloads)

---

## Testing Strategy

### Unit Testing
- Provider logic
- Repository operations
- Plugin registration

### Integration Testing
- Plugin composition
- Event flow
- Data persistence

### UI Testing
- Xcode Previews for rapid iteration
- Screenshot testing for visual regression

---

## Deployment Architecture

### Build Configurations

```
Debug
  ├── Verbose logging
  ├── Debug database (db_debug)
  └── Development tools enabled

Release
  ├── Optimized logging
  ├── Production database (db_production)
  └── Development tools disabled
```

### App Store Integration

**Location**: `AppStore/`
- Purchase handling
- Subscription management
- Receipt validation

---

## Future Extensibility

### Adding New Plugins

1. Create plugin directory in `Plugins/`
2. Implement `SuperPlugin` protocol (actor)
3. Set `static var order` for execution order
4. Implement relevant view methods
5. Plugin auto-discovered at runtime

### Adding New Scenes

1. Implement `addSceneItem()` in plugin
2. Return unique scene name
3. Scene automatically registered

---

## Documentation References

- **CLAUDE.md**: Project overview and development guidelines
- **.cursorrules**: Development best practices
- **README.md**: Product information

---

## Architecture Metrics

- **Total Plugins**: 33
- **Core Framework Size**: ~20 modules
- **SwiftData Models**: 3 primary models
- **Event Types**: 6 categories
- **Storage Locations**: 3 options
- **Platform Support**: macOS, iOS

---

**End of Architecture Code Map**
