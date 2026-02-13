# Cisum Data Model Code Map

**Generated**: 2026-01-21
**Freshness**: Latest
**Scope**: Data models, persistence, repositories, and data flow

---

## Data Architecture Overview

Cisum uses **SwiftData** for persistence with a repository pattern for data access. The data layer supports multiple storage locations (iCloud, local, custom) with automatic synchronization.

### Technology Stack

- **SwiftData** (Primary persistence)
- **CloudKit** (iCloud sync)
- **UserDefaults** (Configuration storage)
- **Combine** (Reactive data flow)

---

## Core Data Models

### SwiftData Models

#### AudioModel

**Location**: `Plugins/Audio/Models/AudioModel.swift` (inferred)

**Purpose**: Represents audio files in the library

**Schema**:
```swift
@Model
final class AudioModel {
  @Attribute(.unique) var url: URL
  var order: Int                    // Randomized order
  var playCount: Int                // Playback count
  var size: Int64                   // File size
  var fileHash: String              // Content hash
  var hasCover: Bool                // Cover art presence
  var isFolder: Bool                // Folder flag
  var metadata: AudioMetadata?       // ID3 tags, etc.
}
```

**Relationships**:
- Parent folder (if isFolder)
- Child files (in folders)

**Indexes**:
- `url` (unique)
- `order` (for sorting)

---

#### BookModel

**Location**: `Plugins/Book/Models/BookModel.swift`

**Purpose**: Represents e-books in the library

**Schema**:
```swift
@Model
final class BookModel {
  @Attribute(.unique) var url: URL
  var bookTitle: String
  var coverData: Data?              // Cover image
  var isCollection: Bool            // Collection flag
  var parent: BookModel?            // Parent collection
  var children: [BookModel]         // Child books
}
```

**Relationships**:
- Parent-child hierarchy for collections
- Cover data stored as binary

**Indexes**:
- `url` (unique)
- `bookTitle` (search)

---

#### CopyTask

**Location**: `Plugins/CopyPlugin/CopyTask.swift`

**Purpose**: Tracks file copy operations

**Schema**:
```swift
@Model
final class CopyTask {
  @Attribute(.unique) var id: UUID
  var sourceURL: URL
  var destinationURL: URL
  var status: CopyStatus
  var progress: Double
  var createdAt: Date
  var completedAt: Date?
}
```

---

## Supporting Data Types

### StorageLocation

**Location**: `Core/Models/StorageLocation.swift`

**Purpose**: Enum for storage location options

**Schema**:
```swift
enum StorageLocation: String, CaseIterable {
  case icloud = "iCloud"
  case local = "Local"
  case custom = "Custom"
}
```

**Persistence**: UserDefaults

**Key**: `"StorageLocation"`

---

### AudioState

**Location**: `Plugins/Audio/Models/AudioState.swift` (inferred)

**Purpose**: Audio playback state

**Properties**:
- Current playing audio
- Playback state (playing/paused)
- Progress
- Playlist position

---

### BookState

**Location**: `Plugins/Book/Models/BookState.swift`

**Purpose**: Book reading state

**Properties**:
- Current book
- Reading progress
- Last position
- Bookmark locations

---

## Data Transfer Objects (DTOs)

### Store DTOs

**Location**: `Plugins/Store/DTO/`

#### ProductDTO
```swift
struct ProductDTO {
  var id: String
  var price: Decimal
  var localizedTitle: String
  var localizedDescription: String
}
```

#### SubscriptionDTO
```swift
struct SubscriptionDTO {
  var productIds: [String]
  var groupDisplayName: String
}
```

#### SubscriptionGroupDTO
```swift
struct SubscriptionGroupDTO {
  var id: String
  var displayName: String
  var subscriptions: [SubscriptionDTO]
}
```

#### ProductGroupsDTO
```swift
struct ProductGroupsDTO {
  var subscriptions: [SubscriptionGroupDTO]
  var nonRenewables: [ProductDTO]
  var consumables: [ProductDTO]
}
```

---

### Book DTOs

**Location**: `Plugins/Book/DTO/`

#### BookDTO
```swift
struct BookDTO {
  var url: URL
  var title: String
  var coverData: Data?
  var isCollection: Bool
}
```

#### BookModelExt+DTO
```swift
extension BookModel {
  func toDTO() -> BookDTO
  static func fromDTO(_ dto: BookDTO) -> BookModel
}
```

---

### Storage DTOs

**Location**: `Plugins/Storage/FileInfo/`

#### FileItem
```swift
struct FileItem {
  var url: URL
  var name: String
  var size: Int64
  var isDirectory: Bool
  var status: FileStatus
}
```

#### FileStatus
```swift
enum FileStatus {
  case local
  case iCloud(progress: Double)
  case error(Error)
}
```

---

## Repository Pattern

### Audio Repositories

**Location**: `Plugins/Audio/Repo/` (inferred)

#### AudioRepo
**Purpose**: Audio data access layer

**Methods**:
```swift
actor AudioRepo {
  func fetchAll() -> [AudioModel]
  func fetch(byURL url: URL) -> AudioModel?
  func save(_ audio: AudioModel)
  func delete(_ audio: AudioModel)
  func updatePlayCount(_ audio: AudioModel)
  func search(query: String) -> [AudioModel]
}
```

#### AudioConfigRepo
**Location**: `Plugins/Audio/AudioConfigRepo.swift`

**Purpose**: Audio configuration storage

**Configuration**:
- Playback settings
- Equalizer settings
- Volume levels

---

### Book Repositories

**Location**: `Plugins/Book/Repo/`

#### BookRepo
**Purpose**: Book data access layer

**Methods**:
```swift
actor BookRepo {
  func fetchAll() -> [BookModel]
  func fetch(byURL url: URL) -> BookModel?
  func fetchCollections() -> [BookModel]
  func save(_ book: BookModel)
  func delete(_ book: BookModel)
  func updateProgress(_ book: BookModel, progress: Double)
}
```

#### BookSettingRepo
**Location**: `Plugins/Book/Repo/BookSettingRepo.swift`

**Purpose**: Book settings storage

**Configuration**:
- Reading preferences
- Font settings
- Display options

---

### UI Repositories

**Location**: `Core/Repo/`

#### UIRepo
**Purpose**: UI state persistence

**Methods**:
```swift
actor UIRepo {
  var showDB: Bool { get set }
  var currentSceneName: String? { get set }
  var windowSize: CGSize { get set }
}
```

#### PluginRepo
**Purpose**: Plugin configuration persistence

**Methods**:
```swift
actor PluginRepo {
  func enabledPlugins() -> [String]
  func setPluginEnabled(_ id: String, enabled: Bool)
  func pluginOrder() -> [String]
  func setPluginOrder(_ order: [String])
}
```

---

## Database Configuration

### Storage Locations

**Location**: `Core/Bootstrap/Config.swift`

```swift
static let databaseDir: URL = MagicApp.getDatabaseDirectory()
static let dbDirName: String = debug ? "db_debug" : "db_production"

static func getDBRootDir() throws -> URL {
  try databaseDir
    .appendingPathComponent(dbDirName, isDirectory: true)
    .createIfNotExist()
}
```

**Paths**:
- Debug: `~/db_debug/`
- Production: `~/db_production/`

---

### CloudKit Integration

**Container**: `iCloud.yueyi.cisum`

**Locations**:
- `cloudDocumentsDir`: iCloud Documents
- `localDocumentsDir`: Local Documents
- `localContainer`: App container

**Sync Logic**:
- Automatic via CloudKit
- NSMetadataQuery for file discovery
- Progress tracking via NSMetadataUbiquitousItemPercentDownloadedKey

**Important**: Download progress returns 0-100, not 0-1

---

## Data Flow

### Read Operations

```
View
  ↓
Repository (Actor)
  ↓
SwiftData Context
  ↓
Model
```

**Example**:
```swift
// View
@Query private var books: [BookModel]

// Repository
let books = await BookRepo().fetchAll()

// SwiftData
let descriptor = FetchDescriptor<BookModel>()
let books = context.fetch(descriptor)
```

---

### Write Operations

```
View
  ↓
Repository (Actor)
  ↓
SwiftData Context
  ↓
Model → CloudKit (if enabled)
```

**Example**:
```swift
// View
Button("Save") {
  Task {
    await BookRepo().save(book)
  }
}

// Repository
context.insert(book)
try? context.save()

// CloudKit
// Automatic sync
```

---

### Event-Driven Updates

```
Model Change
  ↓
Event Posted (NotificationCenter)
  ↓
Views Update (onEvent)
```

**Book Events**:
```swift
// Post
NotificationCenter.post(.bookDBUpdated)

// Listen
View.onBookDBUpdated { _ in
  // Refresh UI
}
```

**Event Types**:
- `.bookDBUpdated`
- `.bookDBSynced`
- `.bookDBDeleted`
- `.bookUpdated`
- `.bookSortingChanged`

---

## Data Synchronization

### iCloud Sync

**Mechanism**: CloudKit automatic sync

**Flow**:
1. User changes storage location to iCloud
2. SwiftData + CloudKit sync enabled
3. Changes propagate to all devices
4. NSMetadataQuery monitors file availability

**Progress Tracking**:
```swift
let percent = metadataItem?.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double
// Note: Returns 0-100, not 0-1
```

---

### Storage Migration

**Location**: `Plugins/Storage/Migrate/`

**Components**:
- `MigrationManager.swift`
- `RepositoryInfoView.swift`
- `MigrationError.swift`
- `MigrationProgressView.swift`

**Process**:
1. User initiates migration
2. Copy files from source to destination
3. Update database URLs
4. Verify file integrity
5. Clean up source (optional)

---

## Data Validation

### Audio Validation

**Supported Formats**:
```swift
static let supportedExtensions = [
  "mp3", "m4a", "flac", "wav"
]
```

**Validation**:
- File extension check
- Hash computation for duplicates
- Metadata extraction

---

### Book Validation

**Validation**:
- File format check
- Cover data size limit
- Title presence

---

## Error Handling

### Data Errors

**Audio Plugin Error**:
```swift
enum AudioPluginError: Error {
  case fileNotFound(URL)
  case invalidFormat(URL)
  case metadataExtractionFailed(URL)
}
```

**Book Plugin Error**:
```swift
enum BookPluginError: Error {
  case invalidBook(URL)
  case coverImageFailed
  case readingProgressFailed
}
```

**Migration Error**:
```swift
enum MigrationError: Error {
  case insufficientSpace
  case copyFailed(URL)
  case databaseUpdateFailed
}
```

---

## Performance Considerations

### Query Optimization

**Indexes**:
- Unique constraints on URLs
- Order fields for sorting

**Fetch Strategies**:
- Lazy loading for large datasets
- Predicate-based filtering
- Batch operations

---

### Memory Management

**Strategies**:
- Actor isolation prevents data races
- Cover data loaded on demand
- Thumbnail generation for images

---

## Data Backup & Recovery

### iCloud Backup

**Automatic**: CloudKit handles backup

**User Data**:
- Audio files
- Book files
- Database state
- User preferences

---

### Local Backup

**Export**: Not currently implemented

**Import**: Not currently implemented

---

## Analytics & Metrics

### Tracked Metrics

**Audio**:
- Play count per file
- Total plays
- Most played

**Book**:
- Reading progress
- Books completed
- Active books

---

## Data Schema Evolution

### Migrations

**Location**: `Plugins/Migrate/`

**Versions**:
- `v25.swift` - Schema version 25

**Migration Strategy**:
- SwiftData automatic migration
- Custom migrations for breaking changes

---

## Testing Data Layer

### Unit Tests

**Repositories**:
- CRUD operations
- Query logic
- Error handling

**Models**:
- Validation logic
- Computed properties

---

### Integration Tests

**Persistence**:
- Save/load cycles
- Database migrations
- CloudKit sync

---

## Data Layer Dependencies

```
SwiftData Models
  ↓
Repositories (Actors)
  ↓
Providers (App, Plugin, State)
  ↓
Views
```

---

## Future Data Enhancements

### Potential Improvements

1. **Smart Playlists**: Rule-based audio playlists
2. **Reading Statistics**: Detailed book reading analytics
3. **Import/Export**: Backup/restore functionality
4. **Batch Operations**: Bulk file operations
5. **Cache Layer**: Improve query performance

---

## Data Metrics

- **SwiftData Models**: 3 primary models
- **Repositories**: 7+ repositories
- **DTOs**: 8+ DTOs
- **Storage Locations**: 3 options
- **Event Types**: 15+ data events

---

**End of Data Model Code Map**
