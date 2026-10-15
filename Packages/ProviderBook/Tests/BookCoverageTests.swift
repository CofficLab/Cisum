import Foundation
import ProviderBook
import Testing
@testable import ProviderBookData

@MainActor
private final class BookProviderStub: BookProviding {
    var bookDisk: URL? { nil }
    var isAvailable: Bool { false }
    func totalCount() async -> Int { 0 }
}

@MainActor @Test
func defaultBookObserverUsesNoopFallback() {
    let provider: any BookProviding = BookProviderStub()
    let handle = provider.addObserver { _ in
        Issue.record("默认书籍观察者不应收到事件")
    }
    #expect(handle is NoopBookProvidingObserverHandle)
    handle.cancel()
    handle.cancel()
}

@MainActor @Test
func explicitBookNoopSupportsRepeatedCancellation() {
    let handle: any BookProvidingObserverHandle = NoopBookProvidingObserverHandle()
    handle.cancel()
    handle.cancel()
}

@Test
func playbackStateDTOTransportsOptionalFieldsAcrossTasks() async {
    let url = URL(fileURLWithPath: "/有声书/第一章.m4b")
    let values = [
        BookPlaybackStateDTO(currentURL: nil, time: nil),
        BookPlaybackStateDTO(currentURL: url, time: nil),
        BookPlaybackStateDTO(currentURL: nil, time: 0),
        BookPlaybackStateDTO(currentURL: url, time: 12.5),
    ]
    let received = await Task.detached { values }.value
    #expect(received == values)
    #expect(received[0].currentURL == nil && received[0].time == nil)
    #expect(received[3].currentURL == url && received[3].time == 12.5)
    for a in received.indices {
        for b in received.indices {
            #expect((received[a] == received[b]) == (a == b))
        }
    }
}

// MARK: - BookSettingRepo

/// UserDefaults 与 NSUbiquitousKeyValueStore 是进程级全局状态，
/// 测试必须串行执行避免相互清除。
@Suite(.serialized)
struct BookSettingRepoTests {
    private static let urlKey = "com.bookplugin.currentBookURL"
    private static let timeKey = "com.bookplugin.currentBookTime"

    private func isolatePreferences() -> () -> Void {
        let defaults = UserDefaults.standard
        let cloud = NSUbiquitousKeyValueStore.default
        let keys = [Self.urlKey, Self.timeKey]
        let localValues = keys.map { defaults.object(forKey: $0) }
        let cloudValues = keys.map { cloud.object(forKey: $0) }
        for key in keys {
            defaults.removeObject(forKey: key)
            cloud.removeObject(forKey: key)
        }
        return {
            for (index, key) in keys.enumerated() {
                if let value = localValues[index] { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
                if let value = cloudValues[index] { cloud.set(value, forKey: key) }
                else { cloud.removeObject(forKey: key) }
            }
            cloud.synchronize()
        }
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
    func storedTimeDistinguishesStoredZeroFromMissingLocalValue() {
        #expect(BookSettingRepo.storedTime(
            localObject: NSNumber(value: 0), localDouble: 0, cloudString: "99"
        ) == 0)
        for localDouble in [0.0, 42.0] {
            #expect(BookSettingRepo.storedTime(
                localObject: nil, localDouble: localDouble, cloudString: "99"
            ) == 99)
            #expect(BookSettingRepo.storedTime(
                localObject: nil, localDouble: localDouble, cloudString: "0"
            ) == 0)
            #expect(BookSettingRepo.storedTime(
                localObject: nil, localDouble: localDouble, cloudString: nil
            ) == nil)
        }
    }

    @Test
    func storedTimeValidatesNonFiniteLocalValuesAndCloudBoundaries() {
        let invalidLocalValues: [TimeInterval] = [-1, .nan, .infinity, -.infinity]
        let invalidCloudValues: [String?] = [nil, "", "abc", "-1", "nan", "inf", "-inf"]
        for localValue in invalidLocalValues {
            #expect(BookSettingRepo.storedTime(
                localObject: NSNumber(value: localValue),
                localDouble: localValue, cloudString: "12.5"
            ) == 12.5)
            for cloudValue in invalidCloudValues {
                #expect(BookSettingRepo.storedTime(
                    localObject: NSNumber(value: localValue),
                    localDouble: localValue, cloudString: cloudValue
                ) == nil)
            }
        }
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
        let restore = isolatePreferences()
        defer { restore() }

        let url = URL(fileURLWithPath: "/books/a.mp3")
        BookSettingRepo.storeCurrent(url)
        #expect(BookSettingRepo.getCurrent() == url)
    }

    @Test
    func storeNilCurrentURLClearsIt() {
        let restore = isolatePreferences()
        defer { restore() }

        BookSettingRepo.storeCurrent(URL(fileURLWithPath: "/books/a.mp3"))
        BookSettingRepo.storeCurrent(nil)
        // 本地 UserDefaults 与 iCloud 均已清空；iCloud 无值时不返回任何内容。
        #expect(BookSettingRepo.getCurrent() == nil)
    }

    @Test
    func storeAndGetCurrentTimeRoundTrips() {
        let restore = isolatePreferences()
        defer { restore() }

        BookSettingRepo.storeCurrentTime(90)
        #expect(BookSettingRepo.getCurrentTime() == 90)
    }

    @Test
    func getCurrentTimeReturnsNilWhenNothingStored() {
        let restore = isolatePreferences()
        defer { restore() }
        #expect(BookSettingRepo.getCurrentTime() == nil)
    }
}
