import Foundation
import ProviderBook
import Testing
@testable import ProviderBookData

// MARK: - 同步通知捕获

/// selector 观察者在 `NotificationCenter.post` 内同步执行，确定性捕获事件。
private final class NotificationCatcher: NSObject {
    var received: Notification?

    @objc
    func handle(_ note: Notification) {
        received = note
    }
}

@MainActor
private func capturedNotification(
    _ name: Notification.Name,
    during post: () -> Void
) -> Notification? {
    let catcher = NotificationCatcher()
    NotificationCenter.default.addObserver(
        catcher,
        selector: #selector(NotificationCatcher.handle(_:)),
        name: name,
        object: nil
    )
    post()
    NotificationCenter.default.removeObserver(catcher)
    return catcher.received
}

// MARK: - BookEvent

@MainActor
struct BookEventTests {
    @Test
    func postMethodsDeliverMatchingNotifications() {
        let cases: [(name: Notification.Name, post: () -> Void)] = [
            (.bookDBSyncing, { NotificationCenter.postBookDBSyncing() }),
            (.bookDBSynced, { NotificationCenter.postBookDBSynced() }),
            (.bookDBUpdated, { NotificationCenter.postBookDBUpdated() }),
            (.bookDBSorting, { NotificationCenter.postBookDBSorting() }),
            (.bookDBSortDone, { NotificationCenter.postBookDBSortDone() }),
        ]

        for testCase in cases {
            let received = capturedNotification(testCase.name) {
                testCase.post()
            }
            #expect(received?.name == testCase.name)
        }
    }

    @Test
    func postBookStateUpdatedCarriesBookURL() {
        let url = URL(fileURLWithPath: "/books/chapter.mp3")
        let received = capturedNotification(.bookStateUpdated) {
            NotificationCenter.postBookStateUpdated(bookURL: url)
        }
        #expect((received?.userInfo?["url"] as? URL) == url)
    }

    @Test
    func postBookDBDeletedCarriesURLs() {
        let urls = [URL(fileURLWithPath: "/books/a.mp3"), URL(fileURLWithPath: "/books/b.mp3")]
        let received = capturedNotification(.bookDBDeleted) {
            NotificationCenter.postBookDBDeleted(urls: urls)
        }
        #expect((received?.userInfo?["urls"] as? [URL]) == urls)
    }

    @Test
    func postBookDBDeletedDefaultsToEmptyURLs() {
        let received = capturedNotification(.bookDBDeleted) {
            NotificationCenter.postBookDBDeleted()
        }
        #expect((received?.userInfo?["urls"] as? [URL]) == [])
    }
}

// MARK: - BookSettingRepo

/// UserDefaults 与 NSUbiquitousKeyValueStore 是进程级全局状态，
/// 测试必须串行执行避免相互清除。
@Suite(.serialized)
struct BookSettingRepoTests {
    private static let urlKey = "com.bookplugin.currentBookURL"
    private static let timeKey = "com.bookplugin.currentBookTime"

    private func clearDefaults() {
        UserDefaults.standard.removeObject(forKey: Self.urlKey)
        UserDefaults.standard.removeObject(forKey: Self.timeKey)
    }

    @Test
    func storedURLParsesAbsoluteURLStrings() {
        let url = URL(string: "file:///books/a.mp3")!
        #expect(BookSettingRepo.storedURL(from: url.absoluteString) == url)
    }

    @Test
    func storedURLParsesLocalPaths() {
        #expect(BookSettingRepo.storedURL(from: "/books/a.mp3") == URL(fileURLWithPath: "/books/a.mp3"))
    }

    @Test
    func storedURLRejectsNilEmptyAndNonPathInputs() {
        #expect(BookSettingRepo.storedURL(from: nil) == nil)
        #expect(BookSettingRepo.storedURL(from: "   ") == nil)
        #expect(BookSettingRepo.storedURL(from: "not-a-path") == nil)
        // 无 scheme 且不以 / 开头的输入按本地路径解析失败 → nil。
        #expect(BookSettingRepo.storedURL(from: "no-scheme-value") == nil)
    }

    @Test
    func storedURLTrimsWhitespace() {
        #expect(BookSettingRepo.storedURL(from: "  /books/a.mp3  ") == URL(fileURLWithPath: "/books/a.mp3"))
    }

    @Test
    func storedTimePrefersValidLocalValue() {
        // localObject 非 nil 且 localDouble 合法 → 用 localDouble。
        let time = BookSettingRepo.storedTime(
            localObject: NSNumber(value: 42.0),
            localDouble: 42.0,
            cloudString: "99.0"
        )
        #expect(time == 42.0)
    }

    @Test
    func storedTimeFallsBackToCloudWhenLocalInvalid() {
        let time = BookSettingRepo.storedTime(
            localObject: NSNumber(value: -5.0),
            localDouble: -5.0,
            cloudString: "99.0"
        )
        #expect(time == 99.0)
    }

    @Test
    func storedTimeRejectsInvalidLocalAndCloud() {
        #expect(BookSettingRepo.storedTime(localObject: nil, localDouble: 0, cloudString: nil) == nil)
        // localDouble 非法（NaN）且 cloudString 非法 → nil。
        #expect(BookSettingRepo.storedTime(localObject: nil, localDouble: .nan, cloudString: "abc") == nil)
        // cloud 负值非法。
        #expect(BookSettingRepo.storedTime(localObject: nil, localDouble: 0, cloudString: "-3") == nil)
    }

    @Test
    func normalizedTimeForStorageFiltersNonFiniteAndNonPositive() {
        #expect(BookSettingRepo.normalizedTimeForStorage(.nan) == 0)
        #expect(BookSettingRepo.normalizedTimeForStorage(.infinity) == 0)
        #expect(BookSettingRepo.normalizedTimeForStorage(-10) == 0)
        #expect(BookSettingRepo.normalizedTimeForStorage(0) == 0)
        #expect(BookSettingRepo.normalizedTimeForStorage(60) == 60)
    }

    @Test
    func storeAndGetCurrentURLRoundTrips() {
        clearDefaults()
        defer { clearDefaults() }

        let url = URL(fileURLWithPath: "/books/a.mp3")
        BookSettingRepo.storeCurrent(url)
        #expect(BookSettingRepo.getCurrent() == url)
    }

    @Test
    func storeNilCurrentURLClearsIt() {
        clearDefaults()
        defer { clearDefaults() }

        BookSettingRepo.storeCurrent(URL(fileURLWithPath: "/books/a.mp3"))
        BookSettingRepo.storeCurrent(nil)
        // 本地 UserDefaults 与 iCloud 均已清空；iCloud 无值时不返回任何内容。
        #expect(BookSettingRepo.getCurrent() == nil)
    }

    @Test
    func storeAndGetCurrentTimeRoundTrips() {
        clearDefaults()
        defer { clearDefaults() }

        BookSettingRepo.storeCurrentTime(90)
        #expect(BookSettingRepo.getCurrentTime() == 90)
    }

    @Test
    func getCurrentTimeReturnsNilWhenNothingStored() {
        clearDefaults()
        defer { clearDefaults() }
        #expect(BookSettingRepo.getCurrentTime() == nil)
    }
}

// MARK: - BookPluginHost

@MainActor
struct BookPluginHostTests {
    @Test
    func getDBRootDirThrowsWhenNotConfigured() {
        BookPluginHost.configure(
            dbRoot: { throw BookPluginError.configurationMissing },
            storageRoot: { nil },
            storageLocationDidChangeNotifications: []
        )
        #expect(throws: BookPluginError.self) {
            try BookPluginHost.getDBRootDir()
        }
    }

    @Test
    func configureProvidesDBRootAndStorageRoot() throws {
        let dbRoot = URL(fileURLWithPath: "/tmp/db")
        let storageRoot = URL(fileURLWithPath: "/tmp/storage")
        BookPluginHost.configure(
            dbRoot: { dbRoot },
            storageRoot: { storageRoot },
            storageLocationDidChangeNotifications: [.bookDBSynced]
        )

        #expect(try BookPluginHost.getDBRootDir() == dbRoot)
        #expect(BookPluginHost.getStorageRoot() == storageRoot)
        #expect(BookPluginHost.storageLocationDidChangeNotifications == [.bookDBSynced])
    }

    @Test
    func getBookDiskUsesBookDirectoryUnderStorageRoot() throws {
        let storageRoot = URL(fileURLWithPath: "/tmp/storage")
        BookPluginHost.configure(
            dbRoot: { URL(fileURLWithPath: "/tmp/db") },
            storageRoot: { storageRoot },
            storageLocationDidChangeNotifications: []
        )

        let disk = BookPluginHost.getBookDisk()
        #expect(disk?.path.hasSuffix("/tmp/storage/\(BookPluginInfo.dirName)") == true)
    }

    @Test
    func getBookDiskReturnsNilWithoutStorageRoot() {
        BookPluginHost.configure(
            dbRoot: { URL(fileURLWithPath: "/tmp/db") },
            storageRoot: { nil },
            storageLocationDidChangeNotifications: []
        )
        #expect(BookPluginHost.getBookDisk() == nil)
    }
}
