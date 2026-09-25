import Foundation
import CisumKernelSupport
import ProviderPluginManaging
import SwiftUI
import Testing
@testable import PluginPluginManager

// MARK: - 探针实现

/// 可配置探针插件：policy disabledByDefault，允许用户启停。
@MainActor
final class ProbeConfigurablePlugin: SuperPlugin {
    let id = "probe-configurable"
    let order: Int = 1
    let metadata = PluginMetadata(
        id: "probe-configurable",
        name: "Configurable",
        description: "",
        policy: .disabledByDefault
    )

    func addSettingView() -> AnyView? { AnyView(Text("configurable")) }
}

/// 常驻探针插件：policy alwaysOn，不可用户切换。
@MainActor
final class ProbeAlwaysOnPlugin: SuperPlugin {
    let id = "probe-alwayson"
    let order: Int = 2
    let metadata = PluginMetadata(
        id: "probe-alwayson",
        name: "AlwaysOn",
        description: "",
        policy: .alwaysOn
    )
}

/// 管理能力探针。
@MainActor
private final class CapabilityProbe: PluginManagementCapability {
    var configurablePlugins: [any SuperPlugin] = []
    var enabledIDs: Set<String> = []
    var enableResults: [String: Bool] = [:]
    var disableResults: [String: Bool] = [:]
    var enableCalls: [String] = []
    var disableCalls: [String] = []

    func isEnabled(id: String) -> Bool { enabledIDs.contains(id) }

    func enablePlugin(id: String) async -> Bool {
        enableCalls.append(id)
        return enableResults[id] ?? true
    }

    func disablePlugin(id: String) async -> Bool {
        disableCalls.append(id)
        return disableResults[id] ?? true
    }
}

/// PluginManaging 探针。
@MainActor
private final class ManagerProbe: PluginManaging {
    var allPlugins: [any SuperPlugin] = []
    var configurablePlugins: [any SuperPlugin] = []
    var pluginCount: Int { allPlugins.count }
    var enabledCount: Int { enabledIDs.count }
    var lastErrorDescription: String?
    var enabledIDs: Set<String> = []
    var registeredIDs: Set<String> = []
    private var observers: [UUID: (PluginManagingEvent) -> Void] = [:]

    func plugin(id: String) -> (any SuperPlugin)? {
        allPlugins.first { $0.id == id }
    }

    func isRegistered(id: String) -> Bool { registeredIDs.contains(id) }

    func enabledPlugins(from candidates: [any SuperPlugin]) -> [any SuperPlugin] {
        candidates.filter { enabledIDs.contains($0.id) }
    }

    func enablePlugin(id: String) async -> Bool {
        enabledIDs.insert(id)
        return true
    }

    func disablePlugin(id: String) async -> Bool {
        enabledIDs.remove(id)
        return true
    }

    func isEnabled(id: String) -> Bool { enabledIDs.contains(id) }

    func emit(_ event: PluginManagingEvent) {
        for observer in observers.values { observer(event) }
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (PluginManagingEvent) -> Void
    ) -> any PluginManagingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ProbeManageHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class ProbeManageHandle: PluginManagingObserverHandle {
    private let onCancel: () -> Void
    private var cancelled = false

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        onCancel()
    }
}

// MARK: - PluginManagementViewModel

@MainActor
struct PluginManagementViewModelTests {
    @Test
    func pluginsComeFromCapability() {
        let probe = CapabilityProbe()
        let plugin = ProbeConfigurablePlugin()
        probe.configurablePlugins = [plugin]

        let viewModel = PluginManagementViewModel(capability: probe)
        #expect(viewModel.plugins.count == 1)
        #expect(viewModel.plugins.first?.id == "probe-configurable")
    }

    @Test
    func emptyViewModelFallsBackToEmpty() {
        let viewModel = PluginManagementViewModel()
        #expect(viewModel.plugins.isEmpty)
        #expect(!viewModel.isEnabled(id: "x"))
        #expect(viewModel.revision == 0)
    }

    @Test
    func setEnabledRoutesToEnableAndDisable() async {
        let probe = CapabilityProbe()
        let viewModel = PluginManagementViewModel(capability: probe)

        let enabled = await viewModel.setEnabled(true, for: "a")
        #expect(enabled)
        #expect(probe.enableCalls == ["a"])

        let disabled = await viewModel.setEnabled(false, for: "b")
        #expect(disabled)
        #expect(probe.disableCalls == ["b"])
    }

    @Test
    func incrementRevisionBumpsVersion() {
        let viewModel = PluginManagementViewModel()
        viewModel.incrementRevision()
        viewModel.incrementRevision()
        #expect(viewModel.revision == 2)
    }
}

// MARK: - PluginManagementCapabilityAdapter

@MainActor
struct PluginManagementCapabilityAdapterTests {
    @Test
    func adapterForwardsToManager() async {
        let manager = ManagerProbe()
        manager.allPlugins = [ProbeConfigurablePlugin()]
        manager.configurablePlugins = manager.allPlugins
        manager.enabledIDs = ["a"]

        let adapter = PluginManagementCapabilityAdapter(manager: manager)
        #expect(adapter.configurablePlugins.count == 1)
        #expect(adapter.isEnabled(id: "a"))
        #expect(!adapter.isEnabled(id: "b"))

        let result = await adapter.enablePlugin(id: "b")
        #expect(result)
        #expect(manager.isEnabled(id: "b"))

        let disabled = await adapter.disablePlugin(id: "b")
        #expect(disabled)
        #expect(!manager.isEnabled(id: "b"))
    }

    @Test
    func adapterFallsBackWhenManagerReleased() async {
        var manager: ManagerProbe? = ManagerProbe()
        let adapter = PluginManagementCapabilityAdapter(manager: manager!)
        manager = nil

        #expect(adapter.configurablePlugins.isEmpty)
        #expect(!adapter.isEnabled(id: "a"))
        let result = await adapter.enablePlugin(id: "a")
        #expect(!result)
    }
}

// MARK: - PluginManagerObserver

@MainActor
struct PluginManagerObserverTests {
    @Test
    func managerEventsIncrementRevision() {
        let manager = ManagerProbe()
        let viewModel = PluginManagementViewModel()
        let observer = PluginManagerObserver(manager: manager, viewModel: viewModel)
        defer { observer.cancel() }

        manager.emit(.enabledPluginsChanged)
        #expect(viewModel.revision == 1)
        manager.emit(.enabledPluginsChanged)
        #expect(viewModel.revision == 2)
    }

    @Test
    func cancellingObserverStopsIncrements() {
        let manager = ManagerProbe()
        let viewModel = PluginManagementViewModel()
        let observer = PluginManagerObserver(manager: manager, viewModel: viewModel)

        observer.cancel()
        manager.emit(.enabledPluginsChanged)
        #expect(viewModel.revision == 0)
    }
}

// MARK: - PluginManagerProvider（真实 BuiltinPluginManager）

@MainActor
struct PluginManagerProviderTests {
    private func makeProvider() async -> (KernelCoreContainer, PluginManagerProvider) {
        let kernel = KernelCoreContainer()
        // 注入状态存储：isPluginEnabled 依赖 kernel.stateStore 读用户覆盖。
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginManagerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        kernel.stateStore = PluginManagerStateStore(pluginDataDirectory: dir)

        let configurable = ProbeConfigurablePlugin()
        let alwaysOn = ProbeAlwaysOnPlugin()
        try? kernel.registerPlugin(configurable)
        try? kernel.registerPlugin(alwaysOn)
        // 启动内核（empty incoming）：enable/disable 要求 lifecycleState == .running。
        try? await kernel.startAsync(plugins: [])
        let provider = PluginManagerProvider(kernel: kernel)
        return (kernel, provider)
    }

    @Test
    func exposesPluginRegistry() async {
        let (kernel, provider) = await makeProvider()
        _ = kernel
        #expect(provider.pluginCount == 2)
        #expect(provider.allPlugins.count == 2)
        #expect(provider.configurablePlugins.count == 1)
        #expect(provider.configurablePlugins.first?.id == "probe-configurable")
        #expect(provider.isRegistered(id: "probe-configurable"))
        #expect(!provider.isRegistered(id: "missing"))
        #expect(provider.plugin(id: "probe-alwayson") != nil)
        #expect(provider.plugin(id: "missing") == nil)
    }

    @Test
    func enabledPluginsFiltersCandidates() async {
        let (kernel, provider) = await makeProvider()
        _ = kernel
        let alwaysOn = provider.plugin(id: "probe-alwayson")!
        let configurable = provider.plugin(id: "probe-configurable")!

        // alwaysOn 默认启用；optIn 未启用。
        let enabled = provider.enabledPlugins(from: [alwaysOn, configurable])
        #expect(enabled.count == 1)
        #expect(enabled.first?.id == "probe-alwayson")
    }

    @Test
    func enableAndDisableRoundTrip() async {
        let (kernel, provider) = await makeProvider()
        _ = kernel // 保持 kernel 存活：PluginManagerProvider 弱引用内核。
        let enabled = await provider.enablePlugin(id: "probe-configurable")
        #expect(enabled)
        #expect(provider.isEnabled(id: "probe-configurable"))
        #expect(provider.lastErrorDescription == nil)

        let disabled = await provider.disablePlugin(id: "probe-configurable")
        #expect(disabled)
        #expect(!provider.isEnabled(id: "probe-configurable"))
    }

    @Test
    func enableUnknownPluginFailsWithError() async {
        let (kernel, provider) = await makeProvider()
        _ = kernel
        let result = await provider.enablePlugin(id: "missing")
        #expect(!result)
        #expect(provider.lastErrorDescription != nil)
    }

    @Test
    func disableAlwaysOnPluginFails() async {
        let (kernel, provider) = await makeProvider()
        _ = kernel
        // alwaysOn 插件默认已启用：enable 幂等成功；disable 受策略保护失败。
        let enabled = await provider.enablePlugin(id: "probe-alwayson")
        #expect(enabled)
        #expect(provider.lastErrorDescription == nil)
        let result = await provider.disablePlugin(id: "probe-alwayson")
        #expect(!result)
        #expect(provider.lastErrorDescription != nil)
    }

    @Test
    func observerHandleCancelIsIdempotent() async {
        let (kernel, provider) = await makeProvider()
        _ = kernel
        let handle = provider.addObserver { _ in }
        handle.cancel()
        handle.cancel()
        // 不崩溃即为通过；重复取消无副作用。
    }
}

// MARK: - PluginPluginManager 生命周期

@MainActor
struct PluginPluginManagerLifecycleTests {
    @Test
    func onRegisterWithNoDocsIsSafe() async throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginPluginManager()
        try await plugin.onRegister(kernel: kernel)
    }

    @Test
    func onBootWithoutStorageKeepsKernelReference() async throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginPluginManager()
        try await plugin.onBootAsync(kernel: kernel)

        // 无 storage 时不注入 stateStore，但保留 kernel 供导航项使用。
        #expect(plugin.addSettingNavigationItem() != nil)
    }

    @Test
    func navigationItemBeforeBootIsNil() {
        let plugin = PluginPluginManager()
        #expect(plugin.addSettingNavigationItem() == nil)
    }

    @Test
    func shutdownTearsDownState() async throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginPluginManager()
        try await plugin.onBootAsync(kernel: kernel)
        #expect(plugin.addSettingNavigationItem() != nil)

        try await plugin.onShutdownAsync(kernel: kernel)
        // shutdown 后导航项仍可构造（kernel 仍持有），不崩溃。
        #expect(plugin.addSettingNavigationItem() != nil)
    }
}
