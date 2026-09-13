@testable import PluginBookLike
import Testing
import Foundation

private final class NotificationObserverToken: @unchecked Sendable {
    var value: NSObjectProtocol?
}

@Test func pluginInfoExportsRegistrationMetadata() {
    #expect(BookLikePluginInfo.iconName == "heart")
    #expect(BookLikePluginInfo.order == 6)
}

@Test
@MainActor
func pluginExposesSettingsNavigationItem() {
    let view = BookLikePlugin.shared.addSettingView()
    let item = BookLikePlugin.shared.addSettingNavigationItem()

    #expect(view == nil)
    #expect(item != nil)
    #expect(item?.id == "liked-books")
    #expect(item?.title == String(localized: "Liked Books", bundle: .module))
}

@Test func bookLikeSettingsUsesLocalizedLoadingText() {
    #expect(BookLikeSettingsView.loadingTextKey == "Loading...")
}

@Test func bookLikeStatusNotificationIsDeliveredOnMainThread() async {
    let url = URL(fileURLWithPath: "/tmp/Cisum Books/Main Thread Book")

    let deliveredOnMainThread = await withCheckedContinuation { continuation in
        let token = NotificationObserverToken()
        token.value = NotificationCenter.default.addObserver(
            forName: .BookLikeStatusChanged,
            object: nil,
            queue: nil
        ) { _ in
            if let observer = token.value {
                NotificationCenter.default.removeObserver(observer)
                token.value = nil
            }
            continuation.resume(returning: Thread.isMainThread)
        }

        Task.detached {
            NotificationCenter.postBookLikeStatusChanged(url: url, liked: true)
        }
    }

    #expect(deliveredOnMainThread)
}

@Test func bookLikeStorePersistsRealLikedBooks() throws {
    let suiteName = "BookLikePluginTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let first = URL(fileURLWithPath: "/tmp/Cisum Books/First Book")
    let second = URL(fileURLWithPath: "/tmp/Cisum Books/Second Book")

    BookLikeStore.setLiked(true, url: second, defaults: defaults)
    BookLikeStore.setLiked(true, url: first, defaults: defaults)

    #expect(BookLikeStore.likedBooks(defaults: defaults).map(\.title) == ["First Book", "Second Book"])

    BookLikeStore.setLiked(false, url: first, defaults: defaults)

    let likedBooks = BookLikeStore.likedBooks(defaults: defaults)
    #expect(likedBooks.count == 1)
    #expect(likedBooks.first?.url == second)
}

@Test func bookLikeStoreMatchesSymlinkedBooks() throws {
    let suiteName = "BookLikePluginTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realBook = root.appendingPathComponent("Real Book", isDirectory: true)
    let linkedBook = root.appendingPathComponent("Linked Book", isDirectory: true)
    defer {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realBook, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedBook, withDestinationURL: realBook)

    BookLikeStore.setLiked(true, url: realBook, defaults: defaults)
    BookLikeStore.setLiked(true, url: linkedBook, defaults: defaults)

    let likedBooks = BookLikeStore.likedBooks(defaults: defaults)
    #expect(likedBooks.count == 1)
    #expect(likedBooks.first?.url == linkedBook)

    BookLikeStore.setLiked(false, url: realBook, defaults: defaults)

    #expect(BookLikeStore.likedBooks(defaults: defaults).isEmpty)
}

@Test func bookLikeStoreKeepsDistinctDanglingSymlinkedBooks() throws {
    let suiteName = "BookLikePluginTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingBook = root.appendingPathComponent("Missing Book", isDirectory: true)
    let firstLink = root.appendingPathComponent("First Book", isDirectory: true)
    let secondLink = root.appendingPathComponent("Second Book", isDirectory: true)
    defer {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: firstLink, withDestinationURL: missingBook)
    try FileManager.default.createSymbolicLink(at: secondLink, withDestinationURL: missingBook)

    BookLikeStore.setLiked(true, url: firstLink, defaults: defaults)
    BookLikeStore.setLiked(true, url: secondLink, defaults: defaults)

    let likedBooks = BookLikeStore.likedBooks(defaults: defaults)
    #expect(likedBooks.map(\.url) == [firstLink, secondLink])

    BookLikeStore.setLiked(false, url: firstLink, defaults: defaults)

    let remaining = BookLikeStore.likedBooks(defaults: defaults)
    #expect(remaining.count == 1)
    #expect(remaining.first?.url == secondLink)
}

@Test func bookLikeStoreIgnoresEmptyStoredURLs() throws {
    let suiteName = "BookLikePluginTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    defaults.set([
        "": "Broken Favorite",
        "file:///tmp/Cisum%20Books/Valid%20Book": "Valid Book",
        "  file:///tmp/Cisum%20Books/Spaced%20Book\n": "Spaced Book",
        "/tmp/Cisum Books/Legacy Book": "Legacy Book",
        "\t/tmp/Cisum Books/Legacy Spaced Book ": "Legacy Spaced Book",
        "not a url": "Invalid Book",
    ], forKey: "BookLikePlugin.likedBooks")

    let likedBooks = BookLikeStore.likedBooks(defaults: defaults)

    #expect(likedBooks.map(\.title) == ["Legacy Book", "Legacy Spaced Book", "Spaced Book", "Valid Book"])
}

// MARK: - ViewModel 集成

@MainActor
private final class BookLikeCapabilityProbe: BookLikePlaybackCapability {
    var isAvailable = true
}

@MainActor
struct BookLikeViewModelTests {
    @Test
    func reloadLoadsLikedBooks() {
        let items = [BookLikeItem(url: URL(fileURLWithPath: "/tmp/book-a"), title: "A")]
        let viewModel = BookLikeViewModel(
            playbackCapability: BookLikeCapabilityProbe(),
            loadLikedBooks: { items },
            saveLikeStatus: { _, _ in }
        )

        viewModel.handleAppear()

        #expect(viewModel.likedBooks == items)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func likeSaveRequiresActiveScene() {
        var saved: [(Bool, URL)] = []
        let viewModel = BookLikeViewModel(
            playbackCapability: BookLikeCapabilityProbe(),
            loadLikedBooks: { [] },
            saveLikeStatus: { liked, url in saved.append((liked, url)) }
        )

        let asset = URL(fileURLWithPath: "/tmp/book-a/chapter.mp3")
        viewModel.handleLikeStatusChanged(asset: asset, liked: true)
        #expect(saved.isEmpty)

        viewModel.handleSceneChange(.audiobooks)
        viewModel.handleLikeStatusChanged(asset: asset, liked: true)
        #expect(saved.count == 1)
        #expect(saved.first?.0 == true)
        #expect(saved.first?.1 == asset)

        viewModel.handleSceneChange(.music)
        viewModel.handleLikeStatusChanged(asset: asset, liked: false)
        #expect(saved.count == 1)
    }

    @Test
    func activationRequiresAvailableCapability() {
        let unavailable = BookLikeCapabilityProbe()
        unavailable.isAvailable = false
        var saved: [(Bool, URL)] = []
        let viewModel = BookLikeViewModel(
            playbackCapability: unavailable,
            loadLikedBooks: { [] },
            saveLikeStatus: { liked, url in saved.append((liked, url)) }
        )

        viewModel.handleSceneChange(.audiobooks)
        viewModel.handleLikeStatusChanged(asset: URL(fileURLWithPath: "/tmp/book-a/chapter.mp3"), liked: true)
        #expect(saved.isEmpty)
    }

    @Test
    func likeStatusChangeReloadsList() {
        var loadCount = 0
        let viewModel = BookLikeViewModel(
            playbackCapability: BookLikeCapabilityProbe(),
            loadLikedBooks: {
                loadCount += 1
                return []
            },
            saveLikeStatus: { _, _ in }
        )

        viewModel.handleSceneChange(.audiobooks)
        viewModel.handleLikeStatusChanged(asset: URL(fileURLWithPath: "/tmp/book-a/chapter.mp3"), liked: true)

        #expect(loadCount >= 1)
    }
}
