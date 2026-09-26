# MagicKit

MagicKit is a general-purpose Swift utility toolkit shared across the **Cisum** app (an audio/music player). It bundles a macOS shell-command subsystem (process, file, network, system, and rich Git operations), iCloud/local directory and download monitoring, a `CKSyncEngine` wrapper, an async HTTP client, thumbnail/cover-art generation, a SwiftUI `AvatarView`, SwiftData convenience extensions, date/time formatting, and a set of logging/event/threading protocols. The single `MagicKit` library ships for **macOS 14+ and iOS 17+**; the shell subsystem is fully implemented on macOS and compiles to a no-op placeholder on iOS.

## Functional Logic

### Core Responsibilities

MagicKit exists to absorb cross-cutting concerns that the Cisum app's feature layers would otherwise duplicate:

- Running shell commands safely (quoting, injection safety, working-directory scoping) and wrapping them into domain-specific helpers (files, processes, network, system info, Git).
- Observing the local file library and its iCloud sync state: directory watching, ubiquitous-item download progress, and one-shot downloads.
- Persisting and reconciling app data with CloudKit through `CKSyncEngine`.
- Producing file thumbnails/covers (images, video frames, audio ID3 artwork, folder icons) with an on-disk cache.
- Providing shared app plumbing: a logging facade (`MagicLogger`), notification posting (`SuperEvent`), queue shortcuts (`SuperThread`), styled log prefixes (`SuperLog`), toast bridging (`ProviderToast`), and common Foundation/SwiftUI extensions.

### Key Modules & Types

#### `Shell/` — shell command execution (macOS; iOS stub)

All shell helpers run commands through `/bin/bash -c`. User-supplied values are single-quote escaped via `shellQuoted(_:)`, and paths beginning with `-` are rewritten to `./…` via `shellPathOperand(_:)` so they cannot be parsed as flags.

- **`Shell/Core/Shell.swift`** — `public class Shell: SuperLog` (emoji `🐚`). The execution engine:
  - `run(_:at:verbose:)` async throws `String`; `runSync(_:at:verbose:)` (throws, `@discardableResult`); `runMultiple(_:at:verbose:)` throws `[String]`; `runWithStatus(_:at:verbose:)` returns `(output: String, exitCode: Int32)`.
  - `isCommandAvailable(_:) -> Bool`, `getCommandPath(_:) -> String?` (via `which`), `configureGitCredentialCache() -> String`.
  - Internal helpers `shellQuoted(_:)` and `commandLookupCommand(_:)`.
  - On iOS it is a class that throws `ShellError.commandFailed` for every method.
- **`Shell/Core/ShellError.swift`** — internal `enum ShellError`: `.commandFailed(output, command)`, `.stringConversionFailed(Data)`, `.processStartFailed(String)`.
- **`Shell/File/ShellFile.swift`** — `class ShellFile: SuperLog` (`📁`). Instance methods `isDirExists(_:)`, `isFileExists(_:)`, `makeDir(_:verbose:)`, `makeFile(_:content:)`, `getFileContent(_:)`, `remove(_:)`, `copy(_:to:)`, `move(_:to:)`, `getFileSize(_:) -> Int`, `listFiles(_:) -> [String]`, `getPermissions(_:)`, `changePermissions(_:permissions:)`. Static `*Command` builders emit e.g. `cat -- '…'`, `rm -rf -- '…'`, `stat -f%z -- '…'`.
- **`Shell/Process/ShellProcess.swift`** — `class ShellProcess: SuperLog` (`⚙️`). Parses `ps aux` lines into `ProcessInfo(pid:user:cpu:memory:command:)` (`fromPSLine(_:)`). Methods: `getAllProcesses()`, `findProcesses(named:)`, `findProcess(pid:)`, `killProcess(pid:)`, `forceKillProcess(pid:)`, `killProcesses(named:)`, `getProcessTree(pid:)`, `getSystemLoad()`, `getMemoryUsage()`, `getTopCPUProcesses(count:)` / `getTopMemoryProcesses(count:)` (sorted with `ps -r` / `-m`), `launchApp(_:withFile:)`, `getRunningApps()`, `isProcessRunning(_:)`, `getProcessDetails(pid:)`, `monitorProcess(pid:)`, `getSystemServices()`, `startService`/`stopService(_:)`. `normalizedPID(_:)` rejects empty, `0`, non-numeric, and full-width digit PIDs.
- **`Shell/Network/ShellNetwork.swift`** — `class ShellNetwork: SuperLog` (`🌐`). `ping(_:)` (default `google.com`), `pingDetailed(_:count:)`, `download(_:to:)`, `curl(_:)`, `getHeaders(_:)`, `testPort(_:port:)` (`nc -z`, port clamped to 1–65535), `getLocalIPs()`, `getPublicIP()`, `getNetworkStatus()`, `getRoutes()`, `getConnections()`, `nslookup(_:)`, `traceroute(_:)`, `getWiFiInfo()` / `scanWiFi()` (via the `airport` binary), `getHTTPStatus(_:) -> Int`, `speedTest()`. Ping count is clamped to 1–100.
- **`Shell/System/ShellSystem.swift`** — `class ShellSystem: SuperLog` (`💻`). `pwd()`, `whoami()`, `uname()`, `systemVersion()`, `cpuInfo()`, `memoryInfo()`, `diskUsage(path:)`, `loadAverage()`, `processes(named:)`, `networkInterfaces()`, `getEnvironmentVariable(_:)`, `getPath()`, `commandExists(_:)`, `systemTime()`, `bootTime()`.

#### `Shell/Git/` — Git wrapper (`public class ShellGit: SuperLog`, `🔧`)

`ShellGit` is extended across many files; every operation takes an optional repo `path`.

**Value types (`Sources/Shell/Git/Git*.swift`):**
- `MagicGitBranch` — `name`, `isCurrent`, `upstream`, `latestCommitHash`, `latestCommitMessage`.
- `MagicGitCommit` — `hash`, `author`, `email`, `date`, `message`, `body`, `refs`, `tags`; `CommitWithTag`; `MagicGitCommitDetail` (adds `files: [MagicGitDiffFile]`, `diff`). Both commit types expose `coAuthors: [String]` and `allAuthors: String` parsed from `Co-Authored-By: Name <email>` trailers (case-insensitive, email optional).
- `MagicGitDiffFile` — `file`, `changeType`, `diff`.
- `MagicGitRemote`, `MagicGitStash`, `MagicGitTag`.

**Operation extensions:**
- *Init/state:* `ShellGitCore` (`initRepository(at:)`), `ShellGitStatus` (`status`, `statusPorcelain`, `stagedFiles`, `unstagedFiles`, `hasUncommittedChanges`; porcelain `-z` parser that skips rename/copy source records), `ShellGitConfig` (`isGitRepository`, `repositoryRoot`, `lastCommitHash(short:)`, `userName`/`userEmail(global:)`, `getUserConfig`, `configUser`).
- *History:* `ShellGitLog` — `log`, `logArray`, `recentCommits`, `commits(in:count:)`, `commitDetail(_:)` (async), `unpushedCommits` / `unpushedCommitList`, `commitsWithTags`, `logsWithPagination`, `commitList`, `commitListWithPagination`. Output is parsed from `git log --pretty=format` using `0x01` (SOH) field separators and `0x02` (STX) record separators so bodies with pipes/newlines survive; tags are extracted from `%d` decorations via `parseDecorationTags`.
- *Branches/checkout:* `ShellGitBranch` (`branches`, `branchesArray`, `currentBranch`, `localBranches`, `remoteBranches`, `allBranches`, `createBranch`, `deleteBranch(force:)`, `lastCommitOfBranch`, `branchList`, `currentBranchInfo`); `ShellGitCheckout` (`checkout`, `checkoutNewBranch`, `checkoutFiles`, `checkoutFile`, `checkoutFileFromCommit`, `checkoutCommit`, `checkoutRemoteBranch`, `checkoutForce`, `checkoutAllFiles`).
- *Staging/committing:* `ShellGitAdd` (`add`, `reset` of staged files), `ShellGitCommit` (`commit(message:)` returns the new HEAD hash via `git rev-parse HEAD`; `addAndCommit(files:message:)`).
- *Clone/remote:* `ShellGitClone` (`clone`, `shallowClone`, `cloneBranch`, `cloneAndGetPath`, `cloneRecursive`, `cloneBare`, `cloneMirror`, `isValidGitRepository` via `git ls-remote`); `ShellGitRemote` (`push`, `pull`, `addRemote`, `remotes(verbose:)`, `remotesArray`, `firstRemoteURL`, `removeRemote`, `setRemoteURL`, `remoteList`).
- *Diff/merge/reset/stash/tag:* `ShellGitDiff` (`diff(staged:)`, `diffFile`, `diffBetweenCommits`, `fileContentChange(at:file:)`, `fileContent(atCommit:file:)`, `fileContentInWorkingDirectory`, `diffFileList`, `fileChanges`, `changedFiles`, `changedFilesDetail`, `uncommittedFileContentChange`, `hasFilesToCommit`; `name-status` / `-z` parsers); `ShellGitMerge` (`merge`, `mergeFastForward`, `mergeNoFastForward`, `mergeSquash`, `mergeWithStrategy`, `mergeAbort`, `mergeContinue`, `isMerging`, `mergeConflictFiles`, `mergeStatus`, `mergeResolveOurs`/`Theirs`); `ShellGitReset` (`reset(mode:)`, `resetHard`, `resetSoft`, `resetMixed`, `resetFile`, `resetStaged`); `ShellGitStash` (`stash(message:)`, `stashPop(index:)`, `stashList`, `stashListArray`); `ShellGitTag` (`tags`, `createTag(message:)`, `deleteTag`, `tags(for:commit:)`, `tagList(for:)`).

#### `Protocols/` — shared behavior mixins

- **`SuperLog.swift`** — `public protocol SuperLog` providing `static emoji`, `static t` (a `[QOS] | emoji Author | ` log prefix), `static author`, `isMain`, `r(_:)`/`makeReason(_:)`, `onAppear`/`onInit`, plus `Thread.currentQosDescription` (`[UI]`/`[IN]`/`[DF]`/`[UT]`/`[BG]`/`[UN]`).
- **`SuperEvent.swift`** — `public protocol SuperEvent` with `emit(_:object:userInfo:)` that posts to `NotificationCenter` on the main thread (off-main emits are hop-hopped via a Sendable payload).
- **`SuperThread.swift`** — `public protocol SuperThread` exposing `main`, `bg`, `background` queues, `f` (`FileManager`), `makeQueue(name:)`, and `threadName`.

#### `Date/`

- **`DateFormatter.swift`** — preconfigured `DateComponentsFormatter.abbreviated` (`2h 30m 15s`), `.positional` (`04:30`), `.relative`; and `RelativeDateTimeFormatter.standard` / `.short`.
- **`ExtDate.swift`** — `Date.now`, `nowCompact`, `fullDateTime` (`yyyy-MM-dd HH:mm:ss`), `compactDateTime` (`yyyyMMddHHmmss`), `logTime` (`HH:mm:ss`), `Date.toString(_:)`, `relativeTime`, `smartRelativeTime`. The internal `DateRelativeTimePolicy` produces "just now / N minutes ago / N hours ago / …" strings (and "… from now" for future dates), switching to `MM-dd` after 7 days.

#### `Http/`

- **`HttpClient.swift`** — fluent async client (`withTimeout`, `withCache(maxAge:)`, `withHeaders`, `withHeader`, `withToken`, `withBody`) with `get()`, `getDataAndResponse()`, `post()`, `put()`, `patch()`, `delete()`, `cancel()`. GET responses can be cached to `Caches/HttpClientCache`, keyed by a SHA-256 of URL+sorted headers; cached JSON is validated before being written. `cacheDirectoryURL()` / `openCacheDirectory()` expose the cache.
- **`HttpError.swift`** — `.ShellError(output:)`, `.HttpNoResponse`, `.HttpStatusError(Int)`, `.HttpNoData`, `.RequestCancelled`.
- **`ExtUrl+HTTP.swift`** — one-shot `URL.httpGet` / `httpGetData` / `httpPost` / `httpPut` / `httpPatch` / `httpDelete` helpers and `URL.httpClient(cacheMaxAge:)`.

#### `File/` and `DownloadMonitor/` — directory & download observation

- **`ICloudDirectoryMonitor.swift`** — `public final class ICloudDirectoryMonitor: SuperLog` (`☁️`). Uses `NSMetadataQuery` scoped to `NSMetadataQueryUbiquitousDocumentsScope` with a path-prefix predicate; callbacks `onChange([URL], isInitial, error)`, `onDeleted([URL])`, `onProgress(URL, Double)`. A direct `FileManager` enumeration is delivered as the authoritative initial snapshot (independent of metadata sync), guarded by `didDeliverInitialScan`, `ICloudDirectoryMonitorLifecycle` (run-token cancellation), and an actor `ProgressThrottle`. `scanDirectoryContents` / `validateDirectoryScanResult` reject silently-empty snapshots for non-empty directories.
- **`LocalDirectoryMonitor.swift`** — `public final class LocalDirectoryMonitor: SuperLog` (`💼`). On macOS uses a `DispatchSourceFileSystemObject` (`open(O_EVTONLY)`, events `.write/.delete/.rename`); on iOS polls every 2 s. `onChange` is an async callback; an actor `MonitorState` tracks first-fetch and last scan time.
- **`GlobalDownloadMonitor.swift`** — internal singleton (`👂`) that owns **one** `NSMetadataQuery` for `NSMetadataUbiquitousItemIsDownloadingKey == YES`, reference-counting per-URL subscribers (`addSubscriber`/`removeSubscriber`) and throttling progress callbacks; emits `1.0` when an item leaves the query.

#### `Sync/` — CloudKit sync

- **`CloudState.swift`** — persists `CKSyncEngine.State.Serialization` as JSON (`CloudStateData{stateSerialization, updatedAt}`) to a URL; `getState()` / `updateState(_:)`; `Error.saveFailed`.
- **`SmartSync.swift`** — `public final actor SmartSync: SuperThread, SuperLog` wrapping `CKSyncEngine` (`automaticallySync = true`). Public `uploadOne` / `upload(_:)` / `delete(_:reason:)` / `deleteZone(zone:)` / `reset()`. Implements `CKSyncEngineDelegate`: state updates persisted via `CloudState`, account-change handling (sign-in re-uploads, sign-out/switch clears local data), fetched record-zone changes merged/deleted through the delegate, and sent-change conflict resolution for `.serverRecordChanged`, `.zoneNotFound`, `.unknownItem`, plus retryable network errors.
- **`SuperCloudModel.swift`** — `public protocol SuperCloudModel` (`uuid`, `privateRecordID`, `zone`, `recordType`, `debugTitle`, `createdAt`, `updatedAt`; equality by `uuid`).
- **`SuperSyncDelegate.swift`** — `public protocol SuperSyncDelegate: Actor` with `onGetModel`, `onMerge`, `onDelete`, `onSaved`, `onClearLastKnownRecord`, `onGetAll`, will/did fetch/send hooks, and `onCloudStateSaveFailed`.

#### `Thumbnail/`

- **`ThumbnailResult.swift`** — `ThumbnailResult(image:isSystemIcon:fileType:source:isCached:)` (`.from(image:isSystemIcon:)` factory; `toSwiftUIImage()`, `hasImage`, `shouldCache`); `ThumbnailSource` (`.generated` / `.systemIcon` / `.cached` / `.downloaded` / `.metadata`); `FileType` (`.image` / `.video` / `.audio` / `.folder` / `.document` / `.unknown`).
- **`Thumbnail+Generator.swift`** — `ThumbnailGenerator(url:size:useDefaultIcon:verbose:reason:)` with `generate() async throws -> ThumbnailResult?`; per-type strategies in `Thumbnail+Audio.swift` (uses `ID3TagEditor` / AVFoundation artwork), `Thumbnail+Image.swift`, `Thumbnail+Video.swift`, `Thumbnail+Folder.swift`.
- **`ExtUrl+ThumbnailCache.swift`** — `ThumbnailCache.shared` (`fetch(for:size:)`, `save(_:for:size:)`, `clearCache()`, `getCacheSize()`, `getCacheDirectory()`).

#### `AvatarView/`

- **`AvatarView.swift`** — `public struct AvatarView: View, SuperLog` (`🚉`). Renders a file's thumbnail with explicit states: `DownloadingView` (progress ring), `ThumbnailView`, `ErrorView`, `LoadingView`, `DefaultIconView`. Configurable via `.magicShape(...)` (circle / rounded rectangle), size, background color, and `monitorDownload`. Subviews are split across `AvatarView+State/Modifiers/Thumbnail/Loading/Error/ErrorView/DefaultIcon/Downloading.swift`.
- **`AvatarDownloadMonitor.swift`** — internal singleton (`📥`) that reference-counts lightweight `resourceValues` polling per URL (rather than a per-view query) and exposes a Combine `CurrentValueSubject<Double, Never>`.

#### `URL/` — URL extensions

- **`ExtUrl+BaseDir.swift`** — convenient directory URLs: `.downloads`, `.documents`, `.caches`, `.temp`, `.applicationSupport`, `.appSpecificSupport`, `.container`, `.cloudContainer`, `.cloudDocuments`, `.database`, `databasePath(filename:)`.
- **`ExtUrl+Type.swift`** — `isAudio` / `isVideo` / `isImage` / `isDocument` (UTType-first, extension-set fallback), `isNetworkURL`, `isFileExist`, `icon` / `systemIcon` / `fastIcon` (SF Symbol names), `checkIsDownloaded(verbose:)`.
- **`ExtUrl+Download.swift`** — `download(verbose:reason:method:onProgress:)` starts `startDownloadingUbiquitousItem` and polls progress; `DownloadMethod.polling(updateInterval:)` / `.query`.
- **`ExtUrl+Events+Downloading.swift`** — `onDownloading(verbose:caller:updateInterval:_:)` and `onDownloadFinished(verbose:caller:_:)` returning `AnyCancellable`, backed by `GlobalDownloadMonitor`.
- **`ExtUrl+FileOps.swift`** — `title`, `isFolder` / `isDirectory` / `isDirExist` / `isNotDirExist`, `copyTo(...)`, `ensureLocalAvailability` / `ensureLocalAvailabilitySync`, sibling navigation `getPrevFile()` / `getNextFile()`, plus policy enums `URLDownloadAvailabilityPolicy`, `URLDownloadProgressPolicy`, `URLDirectoryContainmentPolicy`, and `URLOpenActionPolicy` (`canOpen`, `canRevealInFinder`, `buttonAccessibilityLabel`).
- **`ExtUrl+Thumbnail.swift`** — `thumbnail(size:useDefaultIcon:verbose:reason:)`, `platformThumbnail(...)`, `coverFromMetadata(size:verbose:)`, `thumbnailCacheDirectory()`.
- **`ExtUrl+AudioMetadata.swift`** — `extractCoverFromMetadata(verbose:)` reads artwork via `AVURLAsset` artwork keys.
- **`ExtUrl+AvatarView*.swift`** — `URL.avatarView(...)` builders with shape/size modifiers; `ExtUrl+Log.swift`, `ExtUrl+Samples.swift` provide logging and sample URLs.

#### `Data/`, `Entities/`, `Utils/`, `Thread/`

- **`Data/ExtContext.swift`** — `ModelContext` helpers: `all<T>()`, `paginate(page:descriptor:pageSize:)`, `getCount(for:)` / `count(for:)`, `get(for:)`, `insertAndSave(_:)`, `destroy(for:)`.
- **`Entities/MagicError.swift`** — `MagicError` (`.fileError` / `.networkError` / `.decodingError` / `.encodingError` / `.playerError` / `.invalidFormat` / `.permissionDenied` / `.notImplemented` / `.unknown`) with `wrap(_:)`.
- **`Entities/MagicLogEntry.swift`** — `MagicLogEntry` (`message`, `level`, `caller`, `line`, `timestamp`) with `Level` (`.info` / `.warning` / `.error` / `.debug`, each with a SwiftUI `color` and SF Symbol `icon`).
- **`Entities/ExtError+View.swift`** — `Error.makeView() -> AnyView`.
- **`Utils/MagicApp.swift`** — `public enum MagicApp`: platform flags (`isDesktop`, `isiOS`, `isNotDesktop`, `currentPlatform`), bundle info (`getBundleIdentifier`, `getVersion`, `getAppName`, `getBuildNumber`), `isICloudAvailable()`, device name/model, directory accessors, and a macOS `debugCommand()` `CommandMenu`.
- **`Utils/MagicLogger.swift`** — `public class MagicLogger: ObservableObject` singleton; static `info` / `warning` / `error` / `debug(_:caller:line:)`, `logs` (capped at 1000), `clearLogs()`, mirroring to `os_log`.
- **`Thread/ExtQos.swift`** — `QualityOfService.description(withName:)` (emoji + label per QoS).

#### `Ext/`, `String/`, and top-level extensions

- `ExtCollection.isNotEmpty`; `Data.save(_:)`; `Int.isHttpOkCode()` / `.string` / `.isEven` / `.isOdd` / `padded(length:)` / `.fileSizeString`; `CGSize` (`isSquare` / `isPortrait` / `isLandscape` / `landscape()`, device size constants, non-finite-safe `description`); `TimeInterval.displayFormat` + `TimeFormatter.format(_:)` (`mm:ss` / `h:mm:ss`); `NSMetadataItem` helpers (`fileName`, `fileSize`, `isDirectory`, `url`, `isPlaceholder`, `downloadProgress`, `isUploaded`, `isDownloaded`, `isDownloading`).
- `Image.PlatformImage` typealias (`NSImage` / `UIImage`) with `resize(to:quality:)`, `systemImage`, `fromFile`, `fromCGImage`, `fromCacheData`, `cacheData`, `folderIcon(size:)`, `fromSystemIcon`, `toSwiftUIImage`, `sampleImage(size:)`; `ExtImage+Icons`, `ExtNSImage`, `ExtError+Clipboard`.
- `String`: `toData()`, `toBase64()`, `replaceImageSrcWithRelativePath(_:)`, JSON keypath readers (`getIntFromJSON` / `getStringFromJSON` / `getArrayFromJSON` / `getValueFromJSON`), `copy()`; `withContextEmoji` / `generateContextEmoji()`; SF Symbol name constants (`iconCheckmark`, `iconMusicNote`, `iconICloudDownload`, …); Markdown helpers (`saveMarkdown`, `toMarkdown`, `saveHTMLToMarkdown`); sample strings.

#### Toast bridging

- **`Exports.swift`** — `@_exported import ProviderToast`.
- **`ToastCompatibility.swift`** — `@MainActor enum CisumToastBridge` (install / provider) and the legacy free functions `alert_info`, `alert_success`, `alert_warning`, `alert_error(_:…)`, `alert_loading`, `alert_dismiss_loading`, `alert_dismiss_all`, which route through the shared `ToastProviding`.

### Data Flow / Workflow

- **Shell pipeline:** callers (e.g. `ShellGit`, `ShellFile`, `ShellProcess`) build a quoted command string, then invoke `Shell.runSync` / `Shell.run`, which spawns `/bin/bash -c <command>` (optionally in a working directory), captures stdout via a `Pipe`, routes stderr to a temp file, and throws `ShellError.commandFailed` on a non-zero exit. `runWithStatus` reads combined stdout+stderr with a readability handler and a semaphore timeout.
- **Git flow:** `ShellGit` methods shell out to `git …` in the target repo and parse stable, delimited output (porcelain `-z`, `%x01` / `%x02` pretty formats, `name-status -z`) into the `MagicGit*` value types, which the UI layer then renders.
- **iCloud library observation:** `ICloudDirectoryMonitor` combines an authoritative direct `FileManager` snapshot with `NSMetadataQuery` updates/deletes and per-file progress; `GlobalDownloadMonitor` fans out a single query's progress to per-URL subscribers; `AvatarView` subscribes via `AvatarDownloadMonitor` and reloads its thumbnail when progress reaches 1.0. `URL.download(...)` initiates `startDownloadingUbiquitousItem` and polls until `isDownloaded`.
- **CloudKit sync:** `SmartSync` (an actor) feeds local `SuperCloudModel`s into `CKSyncEngine.pendingRecordZoneChanges`, pulls server changes back through `SuperSyncDelegate.onMerge` / `onDelete`, and persists engine state via `CloudState`.
- **Thumbnails:** `URL.thumbnail(...)` checks `ThumbnailCache` first, otherwise runs `ThumbnailGenerator` (branching on file type / iCloud placeholder / network URL), and caches non-system-icon results.
- **Logging/events:** types conform to `SuperLog` for formatted prefixes, emit via `SuperEvent` on the main thread, and optionally mirror entries into the `MagicLogger` in-memory ring buffer.

### Dependencies

From `Package.swift`:

- **ID3TagEditor** (`chicio/ID3TagEditor`, `from: "4.5.0"`) — used for audio ID3 tag / cover-art reading.
- **ZIPFoundation** (`weichsel/ZIPFoundation`, `from: "0.9.19"`) — archive handling.
- **ProviderToast** (local package, `path: "../ProviderToast"`) — toast presentation; re-exported via `Exports.swift`.

Build settings: swift-tools 6.0, Swift language mode v5, `StrictConcurrency=minimal` enabled on both target and test target; resources from `Resources/` are processed into the bundle.

## Testing Logic

The package ships **31 test files** under `Tests/`, using both Swift Testing (`import Testing`, `@Test` / `#expect`) and XCTest (`XCTestCase`). Most shell/Git tests are gated `#if os(macOS)` because shell execution is unavailable on iOS.

### Test Organization

- **Shell core / file / process / system / network:**
  `ShellCoreTests`, `ShellFileTests`, `ShellProcessTests`, `ShellSystemTests`, `ShellNetworkTests`.
- **Git (one file per command group):**
  `ShellGitAddTests`, `ShellGitBranchTests`, `ShellGitCheckoutTests`, `ShellGitCloneTests`, `ShellGitCommitTests`, `ShellGitConfigTests`, `ShellGitDiffTests`, `ShellGitLogTests`, `ShellGitMergeTests`, `ShellGitRemoteTests`, `ShellGitResetTests`, `ShellGitStashTests`, `ShellGitStatusTests`, `ShellGitTagTests`, plus `CoAuthoredByTest` (XCTest).
- **Date / time:** `DateRelativeTimeTests`, `TimeFormatterTests`.
- **URL / file policies:** `URLOpenActionPolicyTests`, `URLSiblingNavigationTests`, `MagicKitTests` (XCTest, the broad integration file), `MagicKitPerformanceTests` (XCTest).
- **Events / concurrency:** `SuperEventTests`, `CGSizeDescriptionTests`.
- **Directory monitors:** `ICloudDirectoryMonitorTests`, `LocalDirectoryMonitorTests` (XCTest).
- **Placeholder:** `MagicButtonIdTests.swift` (empty file, no tests).

### Key Scenarios Tested

- **Shell safety & quoting:** command strings are built so that malicious/odd input (`git; echo injected $HOME \`uname\`, `"`, `'`) cannot break out — `shellQuoted`, `commandLookupCommand`, leading-dash path handling (`./--file`), and the `ShellFile` / `ShellProcess` / `ShellNetwork` / `ShellSystem` command builders preserve literal inputs. `shellRunSyncHandlesConcurrentCallers` runs 24 concurrent `runSync` calls and asserts outputs are correct and failure-free.
- **Process/network normalization:** `normalizedPID` rejects empty / `0` / non-numeric / full-width PIDs; top-process commands use macOS `ps -r` / `-m` flags and clamp negative counts; ping count clamps to 1–100; invalid ports are rejected; failure messages are fixed English strings.
- **Git parsing:** porcelain `-z` unstaged file parsing (untracked files, staged-only rows ignored, rename/copy source records skipped, destination used after `->`), `name-status` parsers, log line parsing with SOH / `|` separators and pipes preserved in subjects/bodies, ISO-8601 timestamp validation, decoration tag extraction, negative-limit / pagination overflow clamping, and remote verbose-line parsing with spaces in URLs. Real repos are exercised in temp directories for add / checkout / diff working-directory reads.
- **Co-Authored-By:** parsing trailers with/without email, case-insensitive prefix, and propagation from `MagicGitCommitDetail` to `MagicGitCommit`.
- **Date/time:** relative past/future phrasing, invalid/finite clamping, `TimeFormatter` `mm:ss` vs `h:mm:ss` formatting.
- **URL behavior:** `URLOpenActionPolicy` (reveal-in-Finder only for local files/symlinks, accessibility labels), directory size/count skipping hidden files, sibling `getPrevFile` / `getNextFile` over canonicalized directory entries, `toURL` / `toMarkdown` conversions, `copyTo` self-copy / descendant / symlink behaviors, `sameFileLocation` normalization, iCloud placeholder not treated as downloaded, download-progress clamping, and directory-containment prefix matching.
- **Concurrency / events:** `SuperEvent` delivers background emits on the main thread; `CGSize` description stays finite-safe.
- **iCloud monitor:** lifecycle run-token suppression of cancelled delayed starts, replacement-run after stale cancel, direct scan enumerating nested placeholder-like files, accepting an empty readable directory, and rejecting an empty snapshot for a non-empty directory.
- **Logging/perf:** `MagicLogger.clearLogs()` from a background thread dispatches to main; image cropping correctness and a cropping performance test.

### Running Tests

```bash
cd /Users/angel/Code/Coffic/Cisum/Packages/MagicKit
swift test
```

Add `--filter` to run a subset, e.g. `swift test --filter ShellGitLog`. Git and shell tests that touch live processes (`ps`, `which`, `git`) only run on macOS.

### Coverage Notes

- **Strongly covered:** the shell command-string builders and their quoting/injection/leading-dash safety; Git log/status/diff/remote/tag porcelain parsing; Co-Authored-By parsing; relative-time and duration formatting; `URLOpenActionPolicy` and sibling navigation; `SuperEvent` main-thread hop; `CGSize` non-finite formatting; iCloud monitor lifecycle and direct-scan validation.
- **Lightly covered or untested:** `HttpClient` (no dedicated HTTP/cache tests); `SmartSync` / `CloudState` (CloudKit engine, account changes, conflict resolution); `ThumbnailGenerator` / `AvatarView` rendering (only image-cropping helpers and a performance test are exercised); `MagicApp` bundle/directory helpers; `GlobalDownloadMonitor` / `AvatarDownloadMonitor` progress fan-out; `LocalDirectoryMonitor` has only a single file-list-change test. `MagicButtonIdTests.swift` is an empty placeholder.
