import Foundation
import MagicKit
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

/// `BookSettingRepo` 的持久化契约。
///
/// ## 隔离策略
///
/// 每个用例拿到一份**独立的** `UserDefaults` suite 与一份**内存版** iCloud
/// 键值库（``InMemoryCloudKeyValueStore``）。因此：
///
/// - 不读写开发者的真实偏好，也不触碰真实 iCloud 键值库；
/// - 行为不依赖设备是否登录 iCloud —— 换台机器结论完全一致；
/// - 用例之间互不干扰，**不需要 `.serialized`**（旧写法必须串行，
///   是因为它清的是进程级全局状态）。
struct BookSettingRepoTests {
    /// 构造一份隔离的偏好存储。
    ///
    /// - Parameter suiteName: `UserDefaults` suite 名。传 `nil` 时用随机名。
    /// - Parameter cloudValues: iCloud 侧的初始内容。用于模拟
    ///   「值只存在于 iCloud、本地没有」的回退路径。
    private func makePreferences(
        suiteName: String = "BookSettingRepoTests-\(UUID().uuidString)",
        cloudValues: [String: String] = [:]
    ) -> (preferences: PreferenceStore, cloud: InMemoryCloudKeyValueStore) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let cloud = InMemoryCloudKeyValueStore(initialValues: cloudValues)
        return (PreferenceStore(defaults: defaults, cloud: cloud), cloud)
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
        let (preferences, _) = makePreferences()
        let repo = BookSettingRepo(preferences: preferences)

        let url = URL(fileURLWithPath: "/books/a.mp3")
        repo.storeCurrent(url)
        #expect(repo.getCurrent() == url)
    }

    @Test
    func storeNilCurrentURLClearsIt() {
        let (preferences, cloud) = makePreferences()
        let repo = BookSettingRepo(preferences: preferences)

        repo.storeCurrent(URL(fileURLWithPath: "/books/a.mp3"))
        repo.storeCurrent(nil)
        // 本地 UserDefaults 与 iCloud 均已清空；iCloud 无值时不返回任何内容。
        #expect(repo.getCurrent() == nil)
        #expect(cloud.string(forKey: BookSettingRepo.keyOfCurrentBookURL) == nil)
    }

    @Test
    func storeAndGetCurrentTimeRoundTrips() {
        let (preferences, _) = makePreferences()
        let repo = BookSettingRepo(preferences: preferences)

        repo.storeCurrentTime(90)
        #expect(repo.getCurrentTime() == 90)
    }

    @Test
    func getCurrentTimeReturnsNilWhenNothingStored() {
        let (preferences, _) = makePreferences()
        let repo = BookSettingRepo(preferences: preferences)

        #expect(repo.getCurrentTime() == nil)
    }

    // MARK: - 双通道语义

    /// 写入必须**同时**落到本地与 iCloud 两个通道。
    @Test
    func storeWritesToBothLocalAndCloudChannels() {
        let (preferences, cloud) = makePreferences()
        let repo = BookSettingRepo(preferences: preferences)

        repo.storeCurrent(URL(fileURLWithPath: "/books/a.mp3"))
        repo.storeCurrentTime(42)

        #expect(
            preferences.defaults.url(forKey: BookSettingRepo.keyOfCurrentBookURL)
                == URL(fileURLWithPath: "/books/a.mp3")
        )
        #expect(
            cloud.string(forKey: BookSettingRepo.keyOfCurrentBookURL)
                == URL(fileURLWithPath: "/books/a.mp3").absoluteString
        )
        #expect(cloud.string(forKey: BookSettingRepo.keyOfCurrentBookTime) == "42.0")
    }

    /// 本地缺失但 iCloud 有值时，读取应回退到 iCloud，并把结果回填本地。
    @Test
    func readFallsBackToCloudWhenLocalIsMissing() {
        let url = URL(fileURLWithPath: "/books/cloud.mp3")
        let (preferences, _) = makePreferences(
            cloudValues: [BookSettingRepo.keyOfCurrentBookURL: url.absoluteString]
        )
        let repo = BookSettingRepo(preferences: preferences)

        #expect(repo.getCurrent() == url)
        // 回填本地后，后续读取不再依赖 iCloud。
        #expect(
            preferences.defaults.url(forKey: BookSettingRepo.keyOfCurrentBookURL) == url
        )
    }

    /// 本地有值时优先用本地，忽略 iCloud 的不同值。
    @Test
    func readPrefersLocalOverCloud() {
        let local = URL(fileURLWithPath: "/books/local.mp3")
        let (preferences, _) = makePreferences(
            cloudValues: [BookSettingRepo.keyOfCurrentBookURL: "file:///books/cloud.mp3"]
        )
        let repo = BookSettingRepo(preferences: preferences)

        preferences.defaults.set(local, forKey: BookSettingRepo.keyOfCurrentBookURL)
        #expect(repo.getCurrent() == local)
    }
}
