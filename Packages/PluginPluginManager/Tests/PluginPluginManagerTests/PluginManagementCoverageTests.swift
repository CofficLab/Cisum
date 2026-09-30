import Foundation
import KernelCore
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

    func unloadPlugin(id: String) throws {
        allPlugins.removeAll { $0.id == id }
        registeredIDs.remove(id)
        enabledIDs.remove(id)
    }

    func reloadPlugin(id: String) throws {
        // 探针实现：不做实际重载，仅验证可调用。
    }

    func emit(_ event: PluginManagingEvent) {
        for observer in observers.values { observer(event) }
    }

    @discardableResult
    func addPluginObserver(
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
    func pluginsComeFromProvider() {
        let probe = ManagerProbe()
        let plugin = ProbeConfigurablePlugin()
        probe.configurablePlugins = [plugin]

        let viewModel = PluginManagementViewModel(manager: probe)
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
        let probe = ManagerProbe()
        let viewModel = PluginManagementViewModel(manager: probe)

        let enabled = await viewModel.setEnabled(true, for: "a")
        #expect(enabled)
        #expect(probe.isEnabled(id: "a"))

        let disabled = await viewModel.setEnabled(false, for: "b")
        #expect(disabled)
        #expect(!probe.isEnabled(id: "b"))
    }

    @Test
    func incrementRevisionBumpsVersion() {
        let viewModel = PluginManagementViewModel()
        viewModel.incrementRevision()
        viewModel.incrementRevision()
        #expect(viewModel.revision == 2)
    }
    @Test
    func viewModelFallsBackWhenProviderReleased() {
        var manager: ManagerProbe? = ManagerProbe()
        let viewModel = PluginManagementViewModel(manager: manager!)
        manager = nil

        #expect(viewModel.plugins.isEmpty)
        #expect(!viewModel.isEnabled(id: "a"))
    }

    @Test
    func viewModelFailsToEnableAfterProviderReleased() async {
        var manager: ManagerProbe? = ManagerProbe()
        let viewModel = PluginManagementViewModel(manager: manager!)
        manager = nil
        let result = await viewModel.setEnabled(true, for: "a")
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

        manager.emit(.enabledStateChanged(pluginID: "x", enabled: true))
        #expect(viewModel.revision == 1)
        manager.emit(.enabledStateChanged(pluginID: "x", enabled: true))
        #expect(viewModel.revision == 2)
    }

    @Test
    func cancellingObserverStopsIncrements() {
        let manager = ManagerProbe()
        let viewModel = PluginManagementViewModel()
        let observer = PluginManagerObserver(manager: manager, viewModel: viewModel)

        observer.cancel()
        manager.emit(.enabledStateChanged(pluginID: "x", enabled: true))
        #expect(viewModel.revision == 0)
    }
}

// MARK: - PluginPluginManager 生命周期

@MainActor
struct PluginPluginManagerLifecycleTests {
    @Test
    func onRegisterWithNoDocsIsSafe() throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginPluginManager()
        try plugin.onRegister(kernel: kernel)
    }

    @Test
    func onBootWithoutStorageKeepsKernelReference() async throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginPluginManager()
        try await plugin.onBootAsync(kernel: kernel)

        // 无 storage 时不注入 stateStore，但保留 kernel 供导航项使用。
        #expect(plugin.makeSettingEntry() != nil)
    }

    @Test
    func navigationItemBeforeBootIsNil() {
        let plugin = PluginPluginManager()
        #expect(plugin.makeSettingEntry() == nil)
    }

    @Test
    func shutdownTearsDownState() async throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginPluginManager()
        try await plugin.onBootAsync(kernel: kernel)
        #expect(plugin.makeSettingEntry() != nil)

        try await plugin.onShutdownAsync(kernel: kernel)
        // shutdown 后导航项仍可构造（kernel 仍持有），不崩溃。
        #expect(plugin.makeSettingEntry() != nil)
    }
}
