import CisumProviderStorage
import Foundation
import Testing
@testable import PluginStorage

// MARK: - 测试替身

/// 可控的存储 Provider 替身。
@MainActor
final class StubStorageProvider: StorageProviding {
    var currentStorageLocation: StorageLocation?
    var storageRoot: URL?
    var hasUsableStorageLocation: Bool = true
    var isICloudStorageAvailable: Bool = true

    /// 记录收到的写入请求。
    private(set) var setLocationCalls: [StorageLocation?] = []

    private(set) var observerCount = 0
    private(set) var cancelledCount = 0
    private var callback: ((StorageProvidingEvent) -> Void)?

    init(location: StorageLocation? = .local, root: URL? = URL(fileURLWithPath: "/tmp/storage")) {
        self.currentStorageLocation = location
        self.storageRoot = root
    }

    func storageRoot(for location: StorageLocation) -> URL? {
        switch location {
        case .icloud: isICloudStorageAvailable ? storageRoot : nil
        case .local: storageRoot
        case .custom: nil
        }
    }

    func setStorageLocation(_ location: StorageLocation?) {
        setLocationCalls.append(location)
        currentStorageLocation = location
        callback?(.locationChanged(location))
    }

    func resetStorageLocation() {
        currentStorageLocation = nil
        callback?(.locationChanged(nil))
    }

    // MARK: - 数据库侧能力（本插件不消费，仅为满足协议）

    var databaseRoot: URL {
        URL(fileURLWithPath: "/tmp/cisum-storage/databases", isDirectory: true)
    }

    func databaseFile(name: String) throws -> URL {
        databaseRoot.appendingPathComponent(name, isDirectory: true)
            .appendingPathComponent("\(name).db")
    }

    func pluginDataDirectory(for pluginID: String) -> URL {
        databaseRoot.appendingPathComponent(pluginID, isDirectory: true)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (StorageProvidingEvent) -> Void
    ) -> any StorageProvidingObserverHandle {
        observerCount += 1
        self.callback = callback
        return StubStorageHandle { [weak self] in
            self?.cancelledCount += 1
            self?.callback = nil
        }
    }

    /// 模拟存储可用性变化。
    func emitAvailabilityChanged() {
        callback?(.storageAvailabilityChanged)
    }

    /// 模拟存储位置变化。
    func emitLocationChanged(_ location: StorageLocation?) {
        callback?(.locationChanged(location))
    }
}

@MainActor
final class StubStorageHandle: StorageProvidingObserverHandle {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}

// MARK: - 存储能力适配器

/// 存储能力适配器把内核的 `StorageProviding` 收窄为设置页需要的一小组成员。
///
/// 关键语义：
/// 1. **Provider 缺失 → 退化为「无存储位置」**，而不是崩溃；
/// 2. **两种内核事件合并为一种 `.changed`**——设置页对二者的响应一致；
/// 3. **写入能力保留**——迁移完成后需要提交新的存储位置。
@Suite("存储设置能力适配器")
@MainActor
struct StorageSettingsCapabilityAdapterTests {
    @Test("透出当前存储位置")
    func exposesCurrentLocation() {
        let provider = StubStorageProvider(location: .icloud)
        let adapter = StorageSettingsCapabilityAdapter(storage: provider)

        #expect(adapter.currentStorageLocation == .icloud)
    }

    @Test("透出存储根目录")
    func exposesStorageRoot() {
        let root = URL(fileURLWithPath: "/tmp/cisum-storage")
        let provider = StubStorageProvider(root: root)
        let adapter = StorageSettingsCapabilityAdapter(storage: provider)

        #expect(adapter.storageRoot == root)
    }

    @Test("Provider 缺失时退化为无存储位置")
    func missingProviderDegradesGracefully() {
        let adapter = StorageSettingsCapabilityAdapter(storage: nil)

        #expect(adapter.currentStorageLocation == nil)
        #expect(adapter.storageRoot == nil)
        #expect(adapter.isICloudStorageAvailable == false)
        #expect(adapter.storageRoot(for: .local) == nil)
    }

    @Test("Provider 缺失时写入是安全的空操作")
    func missingProviderIgnoresWrite() {
        let adapter = StorageSettingsCapabilityAdapter(storage: nil)
        // 不应崩溃。
        adapter.setStorageLocation(.local)
    }

    @Test("按位置解析存储根目录")
    func resolvesRootForLocation() {
        let root = URL(fileURLWithPath: "/tmp/cisum-storage")
        let provider = StubStorageProvider(root: root)
        let adapter = StorageSettingsCapabilityAdapter(storage: provider)

        #expect(adapter.storageRoot(for: .local) == root)
        #expect(adapter.storageRoot(for: .icloud) == root)
    }

    @Test("iCloud 不可用时该位置的根目录为 nil")
    func icloudRootIsNilWhenUnavailable() {
        let provider = StubStorageProvider(root: URL(fileURLWithPath: "/tmp/cisum-storage"))
        provider.isICloudStorageAvailable = false
        let adapter = StorageSettingsCapabilityAdapter(storage: provider)

        #expect(adapter.storageRoot(for: .icloud) == nil)
        #expect(adapter.storageRoot(for: .local) != nil)
    }

    @Test("写入会被转发到 Provider")
    func forwardsWrite() {
        let provider = StubStorageProvider(location: .local)
        let adapter = StorageSettingsCapabilityAdapter(storage: provider)

        adapter.setStorageLocation(.icloud)

        #expect(provider.setLocationCalls.count == 1)
        #expect(provider.setLocationCalls.first == .icloud)
    }

    @Test("位置变更事件被转发")
    func forwardsLocationChange() {
        let provider = StubStorageProvider(location: .local)
        let adapter = StorageSettingsCapabilityAdapter(storage: provider)

        var changeCount = 0
        let handle = adapter.addObserver { _ in changeCount += 1 }

        provider.emitLocationChanged(.icloud)
        #expect(changeCount == 1)

        handle.cancel()
    }

    @Test("可用性变化事件被转发")
    func forwardsAvailabilityChange() {
        let provider = StubStorageProvider(location: .local)
        let adapter = StorageSettingsCapabilityAdapter(storage: provider)

        var changeCount = 0
        let handle = adapter.addObserver { _ in changeCount += 1 }

        provider.emitAvailabilityChanged()
        #expect(changeCount == 1)

        handle.cancel()
    }

    @Test("订阅会真正注册到 Provider 上")
    func subscriptionReachesProvider() {
        let provider = StubStorageProvider(location: .local)
        let adapter = StorageSettingsCapabilityAdapter(storage: provider)

        let handle = adapter.addObserver { _ in }
        #expect(provider.observerCount == 1)

        handle.cancel()
        #expect(provider.cancelledCount == 1)
    }

    @Test("Provider 缺失时订阅返回可安全取消的句柄")
    func missingProviderReturnsCancellableHandle() {
        let adapter = StorageSettingsCapabilityAdapter(storage: nil)

        var notified = false
        let handle = adapter.addObserver { _ in notified = true }
        handle.cancel()
        handle.cancel()

        #expect(notified == false)
    }
}

// MARK: - 设置页 ViewModel

/// 设置页 ViewModel 每次刷新都要从能力读取当前位置与可用性。
/// 能力缺失时必须显示「未配置」而不是沿用上一次的旧值。
@Suite("存储设置状态容器")
@MainActor
struct StorageSettingsViewModelTests {
    @Test("初始化时读取当前状态")
    func readsStateOnInit() {
        let provider = StubStorageProvider(location: .icloud)
        let adapter = StorageSettingsCapabilityAdapter(storage: provider)

        let viewModel = StorageSettingsViewModel(storage: adapter)

        #expect(viewModel.location == .icloud)
        #expect(viewModel.isICloudAvailable)
        #expect(viewModel.isLocalStorageAvailable)
    }

    @Test("能力缺失时状态为空")
    func degradesWithoutCapability() {
        let viewModel = StorageSettingsViewModel(storage: nil)

        #expect(viewModel.location == nil)
        #expect(viewModel.isICloudAvailable == false)
        #expect(viewModel.isLocalStorageAvailable == false)
        #expect(viewModel.storageRoot == nil)
    }

    @Test("Provider 变化后重新绑定会刷新状态")
    func rebindingRefreshesState() {
        let viewModel = StorageSettingsViewModel(storage: nil)
        #expect(viewModel.location == nil)

        let provider = StubStorageProvider(location: .local)
        viewModel.updateStorage(StorageSettingsCapabilityAdapter(storage: provider))

        #expect(viewModel.location == .local)
    }

    @Test("切换存储位置会写入能力")
    func settingLocationForwardsWrite() {
        let provider = StubStorageProvider(location: .local)
        // 注意：适配器必须由测试自己持有——它对 Provider 是 `weak`，
        // 临时创建的适配器会在初始化后立即释放，能力随之退化为空值。
        let adapter = StorageSettingsCapabilityAdapter(storage: provider)
        let viewModel = StorageSettingsViewModel(storage: adapter)

        viewModel.setStorageLocation(.icloud)

        #expect(provider.setLocationCalls.count == 1)
        #expect(provider.setLocationCalls.first ?? nil == .icloud)
    }

    @Test("Provider 变化通知会刷新状态")
    func providerChangeRefreshesState() {
        let provider = StubStorageProvider(location: .local)
        let adapter = StorageSettingsCapabilityAdapter(storage: provider)
        let viewModel = StorageSettingsViewModel(storage: adapter)

        provider.currentStorageLocation = .icloud
        viewModel.handleProviderChanged()

        #expect(viewModel.location == .icloud)
    }
}
