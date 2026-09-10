import Combine
import CisumUIComponents
import Foundation
import SwiftUI

/// Cisum 轻量级内核容器。
///
/// ## 架构原则
///
/// Kernel 只持有各类能力（Provider），不做能力转发。
///
/// 错误示例:
/// ```swift
/// kernel.getAudioList()  // ❌ Kernel 会无限膨胀
/// ```
///
/// 正确示例:
/// ```swift
/// kernel.audio.getAudioList()  // ✅ 能力委托给具体 Provider
/// ```
///
/// 所有具体实现通过 Provider 协议注入，Kernel 不依赖具体实现类。
///
/// ## 使用示例
///
/// ```swift
/// let kernel = CisumKernelContainer()
/// kernel.registerStorage(myStorageProvider)
/// kernel.registerPlayback(myPlaybackService)
/// try await kernel.startup()
///
/// // 消费服务
/// let location = kernel.storage?.currentLocation
/// kernel.playback?.togglePlayPause()
/// ```
@MainActor
public final class CisumKernelContainer: ObservableObject {
    // MARK: - Service Registry

    /// 服务注册表，以协议类型为键存储已注册的服务实例。
    private var services: [ObjectIdentifier: Any] = [:]

    /// 服务变化订阅（用于转发 ObservableObject 的 objectWillChange）。
    private var serviceSubscriptions: [ObjectIdentifier: AnyCancellable] = [:]

    /// Provider → 注册它的插件 ID。宿主在插件启动前注册的基础设施 Provider
    /// （activePluginID 为 nil 时）不写此表，表示不归任何插件所有。
    /// 用于诊断「某个 Provider 是被谁注入的」，以及为未来"插件禁用时自动撤回"
    /// 预留归属信息。
    private var providerOwners: [ObjectIdentifier: String] = [:]

    /// 当前正在执行生命周期的插件 ID。由 `BuiltinPluginManager` 在每次调用
    /// 插件 `onRegister` / `onBoot` / `onReady` / `onEnable` / `onDisable` /
    /// `onShutdown` 前后设置/清空；`registerProvider` 据此记录归属。
    ///
    /// 对齐 Lumi `KernelCore+Plugin` 的 `activePluginID` 机制。
    public var activePluginID: String?

    /// 内置插件管理器。
    public let pluginManager: BuiltinPluginManager

    /// 插件启用状态持久化存储（对齐 Lumi `KernelCore.stateStore`）。
    ///
    /// 由存储插件在 `onBoot` 注入（写入 `<databaseRoot>/PluginManager/`）；
    /// 未注入时插件启用状态回落策略默认值、运行期启停不持久化。
    public var stateStore: (any PluginStatePersisting)?

    /// 内核统一事件分发器。
    public let eventManager: EventManager

    // MARK: - Initialization

    public init() {
        self.eventManager = EventManager()
        self.pluginManager = BuiltinPluginManager()
        self.pluginManager.kernel = self
    }

    // MARK: - Generic Service Registry

    /// 注册服务实现。
    ///
    /// 如果服务实现了 `ObservableObject`，内核会自动将其 `objectWillChange`
    /// 转发到自身，使得依赖该服务的 SwiftUI 视图能正确刷新。
    ///
    /// 重复注册同一协议类型时抛 `CisumKernelError.providerAlreadyRegistered`
    /// （对齐 Lumi 语义）。要替换已有 Provider，必须先显式调用
    /// `unregisterProvider(_:)`，避免「静默换人」把依赖旧实例的弱引用打成
    /// 空号——这是 `ScenePlugin` 曾经踩过的那类 bug。
    ///
    /// - Parameters:
    ///   - type: 协议类型。
    ///   - provider: 服务实例。
    /// - Throws: `CisumKernelError.providerAlreadyRegistered` 重复注册。
    public func registerProvider<T>(_ type: T.Type, _ provider: T) throws {
        let key = ObjectIdentifier(type)
        if services[key] != nil {
            throw CisumKernelError.providerAlreadyRegistered(
                type: type,
                owner: providerOwners[key]
            )
        }
        services[key] = provider
        if let owner = activePluginID {
            providerOwners[key] = owner
        }
        subscribeToObjectWillChange(observable: provider, key: key)
    }

    /// 解析已注册的服务。
    ///
    /// - Parameter type: 协议类型，默认从返回值类型推导。
    /// - Returns: 已注册的服务实例，未注册时返回 `nil`。
    public func resolveProvider<T>(_ type: T.Type = T.self) -> T? {
        services[ObjectIdentifier(type)] as? T
    }

    /// 移除已注册的服务。
    ///
    /// - Parameter type: 协议类型。
    public func unregisterProvider<T>(_ type: T.Type) {
        let key = ObjectIdentifier(type)
        services.removeValue(forKey: key)
        serviceSubscriptions.removeValue(forKey: key)
        providerOwners.removeValue(forKey: key)
    }

    // MARK: - 兼容别名（对齐 Lumi KernelCore 命名；旧名保留为薄封装）

    @available(*, deprecated, renamed: "registerProvider")
    public func registerService<T>(_ type: T.Type, _ instance: T) throws {
        try registerProvider(type, instance)
    }

    @available(*, deprecated, renamed: "resolveProvider")
    public func resolveService<T>(_ type: T.Type = T.self) -> T? {
        resolveProvider(type)
    }

    @available(*, deprecated, renamed: "unregisterProvider")
    public func unregisterService<T>(_ type: T.Type) {
        unregisterProvider(type)
    }

    // MARK: - Private Helpers

    /// 订阅 ObservableObject 的 objectWillChange，转发到内核自身的 objectWillChange。
    private func subscribeToObjectWillChange<T>(observable: T, key: ObjectIdentifier) {
        guard let observableObject = observable as? any ObservableObject else { return }
        let publisher = observableObject.objectWillChange as! ObservableObjectPublisher
        serviceSubscriptions[key] = publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.objectWillChange.send()
            }
    }

    // MARK: - Startup

    /// 启动内核，执行自检和初始化流程。
    ///
    /// 启动顺序:
    /// 1. 插件系统 OnBoot — 注册内核服务（alwaysOn 优先，其后可配置）
    /// 2. 服务校验 — 必需服务（Storage / Playback / Plugin / Theme）检查
    /// 3. 插件系统 OnReady — 依赖服务的异步初始化
    /// 4. 贡献聚合 — 失效插件视图缓存，并将主题贡献同步到 CisumUI
    ///
    /// - Throws: `CisumKernelError.missingRequiredServices` 如果必需服务缺失。
    public func startup() async throws {
        // 阶段 1: 插件 OnBoot — 注册核心服务
        try await pluginManager.onBoot(kernel: self)

        // 阶段 2: 服务校验
        let missingServices: [String] = [
            storage == nil ? "Storage" : nil,
            playback == nil ? "Playback" : nil,
            plugin == nil ? "Plugin" : nil,
            theme == nil ? "Theme" : nil,
        ].compactMap { $0 }

        if !missingServices.isEmpty {
            throw CisumKernelError.missingRequiredServices(missingServices)
        }

        // 阶段 3: 插件 OnReady — 异步初始化
        try await pluginManager.onReady(kernel: self)

        // 阶段 4: 贡献聚合 — 失效缓存并将主题同步到 CisumUI
        pluginManager.registerPluginUIContributions(in: self)
    }

    /// 关闭内核，停止并注销全部插件。
    ///
    /// 已启动插件按启动逆序执行 `onShutdown`，随后全部插件逆序执行
    /// `onUnregister`，最后清空插件注册表。单插件清理失败不阻断其余插件。
    public func shutdown() async {
        await pluginManager.shutdown(kernel: self)
    }
}

/// KernelCore 对外暴露的内核类型；保留 CisumKernelContainer 作为实现名，
/// 以兼容现有 Cisum 调用方。
public typealias KernelCore = CisumKernelContainer

/// 兼容别名: 使用 `CisumKernel` 替代 `CisumKernelContainer`。
public typealias CisumKernel = CisumKernelContainer
