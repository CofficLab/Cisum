import Foundation
import MagicKit
import ObjectiveC.runtime
import OSLog
import StoreKit
import SwiftData
import SwiftUI

/// 插件提供者
///
/// 负责管理应用中的所有插件，包括插件的注册、发现、激活和生命周期管理。
/// 提供插件视图的包裹、工具栏按钮、状态视图和弹窗视图的统一管理。
///
/// ## 主要功能
/// - 自动发现和注册插件
/// - 管理当前激活的分组插件
/// - 提供插件视图的链式包裹功能
/// - 统一管理插件提供的各类视图组件
///
/// ## 注意事项
/// - 该类必须在主线程上使用（`@MainActor`）
/// - 插件按注册顺序进行视图包裹
@MainActor
class PluginProvider: ObservableObject, SuperLog, SuperThread {
    nonisolated static let emoji = "🧩"
    static let verbose = false

    /// 插件仓库，用于持久化插件配置
    private let repo: PluginRepo

    /// 所有已注册的插件列表
    @Published private(set) var plugins: [SuperPlugin] = []

    /// 当前激活的场景名称
    @Published private(set) var currentSceneName: String?

    /// 获取所有可用的场景名称
    @MainActor
    var sceneNames: [String] {
        plugins.compactMap { $0.addSceneItem() }
    }
    
    // MARK: - Plugin Registration
    
    /// 已注册的插件实例列表
    private var registeredPlugins: [any SuperPlugin] = []
    
    /// 已使用的插件 ID 集合（用于检测重复）
    private var usedIds: Set<String> = []
    
    /// 线程安全的注册队列
    private let registrationQueue = DispatchQueue(label: "com.cofficlab.pluginprovider.registration", attributes: .concurrent)

    /// 初始化插件提供者
    ///
    /// 使用预定义的插件列表初始化，并尝试恢复上次激活的场景。
    ///
    /// - Parameters:
    ///   - plugins: 预定义的插件列表
    ///   - repo: 插件仓库，用于持久化插件配置
    init(plugins: [SuperPlugin], repo: PluginRepo) {
        self.plugins = plugins
        self.repo = repo

        // 恢复上次激活的场景
        let savedSceneName = repo.getCurrentSceneName()
        if sceneNames.contains(savedSceneName) {
            self.currentSceneName = savedSceneName
        } else if let firstScene = sceneNames.first {
            self.currentSceneName = firstScene
            repo.storeCurrentSceneName(firstScene)
        }
    }

    /// 初始化插件提供者（支持自动发现）
    ///
    /// 如果启用自动发现，将自动扫描并注册所有插件。
    /// 这是推荐的初始化方式，可以自动发现项目中的所有插件。
    ///
    /// - Parameters:
    ///   - repo: 插件仓库，用于持久化插件配置
    init(repo: PluginRepo) {
        if Self.verbose {
            os_log("\(Self.t)🚀 初始化开始")
        }

        self.repo = repo

        // 自动发现并注册所有插件
        autoDiscoverAndRegisterPlugins()

        // 从内部注册表获取所有已注册的插件实例
        self.plugins = getAllPlugins()

        // 验证插件架构约束
        validatePluginArchitecture()

        // 恢复上次激活的场景
        let savedSceneName = self.repo.getCurrentSceneName()
        if sceneNames.contains(savedSceneName) {
            self.currentSceneName = savedSceneName
        } else if let firstScene = sceneNames.first {
            self.currentSceneName = firstScene
            repo.storeCurrentSceneName(firstScene)
        }

        if Self.verbose {
            os_log("\(Self.t)✅ 初始化完成，插件数量: \(self.plugins.count)")

            let scenePlugins = plugins.compactMap { plugin -> String? in
                plugin.addSceneItem()
            }

            os_log("\(Self.t)🎭 场景插件: \(scenePlugins.joined(separator: ", "))")
        }
    }

    /// 获取所有插件提供的状态视图
    ///
    /// 遍历所有已注册的插件，收集它们提供的状态视图（如果有）。
    /// 状态视图通常显示在应用的状态栏或顶部区域。
    ///
    /// - Returns: 包含所有插件状态视图的数组
    func getStatusViews() -> [AnyView] {
        let items = plugins.compactMap { $0.addStatusView() }

        // os_log("\(self.t)GetRootViews: \(items.count)")

        return items
    }

    /// 获取所有插件提供的标签页视图
    ///
    /// 遍历所有已注册的插件，收集它们提供的标签页视图（如果有）。
    /// 标签页视图通常用于在特定场景下显示多个标签页。
    ///
    /// - Parameters:
    ///   - reason: 调用原因，通常为调用者的类名
    ///   - demoMode: 是否处于 Demo 模式，默认为 false
    /// - Returns: 包含所有插件标签页视图的数组
    func getTabViews(reason: String, demoMode: Bool = false) -> [(view: AnyView, label: String)] {
        let tabViews = plugins.compactMap { plugin in
            plugin.addTabView(reason: reason, currentSceneName: currentSceneName, demoMode: demoMode)
        }

        if Self.verbose {
            os_log("\(self.t)📑 getTabViews: \(tabViews.count) 个标签页")
        }

        return tabViews
    }

    /// 将内容依序用所有插件的 RootView 包裹（链式装配）
    ///
    /// 按照插件注册顺序，依次用每个插件的 `addRootView` 方法包裹内容视图。
    /// 这实现了类似中间件的功能，每个插件可以在视图层级中添加自己的包装层。
    ///
    /// ## 工作原理
    /// 1. 从原始内容开始
    /// 2. 按 `plugins` 数组顺序遍历
    /// 3. 每个插件可以选择包裹当前视图或直接返回
    /// 4. 最终返回完全包裹后的视图
    ///
    /// ## 示例
    /// ```swift
    /// // 假设有三个插件 A, B, C
    /// // 最终视图层级：A(B(C(原始内容)))
    /// ```
    ///
    /// - Parameter content: 需要被包裹的原始视图内容
    /// - Returns: 经过所有插件包裹后的视图，如果没有插件则返回原始内容
    func wrapWithCurrentRoot<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        var wrapped: AnyView = AnyView(content())

        for plugin in plugins {
            wrapped = plugin.wrapRoot(wrapped)
        }

        return wrapped
    }


    /// 获取所有插件提供的工具栏按钮
    ///
    /// 遍历所有已注册的插件，收集它们提供的工具栏按钮。
    /// 每个按钮包含唯一的 ID 和对应的视图。
    ///
    /// - Returns: 包含按钮 ID 和视图的元组数组
    func getToolBarButtons() -> [(id: String, view: AnyView)] {
        let buttons = plugins.flatMap { $0.addToolBarButtons() }

        if Self.verbose {
            os_log("\(self.t)🏃 getToolBarButtons: \(buttons.count)")
        }

        return buttons
    }

    /// 设置当前激活的场景
    ///
    /// 将指定的场景名称设置为当前激活的场景，并持久化该选择。
    ///
    /// - Parameter sceneName: 要激活的场景名称
    /// - Throws: `PluginProviderError.sceneNotFound` 如果场景不存在
    @MainActor
    func setCurrentScene(_ sceneName: String) throws {
        let oldSceneName = self.currentSceneName ?? "nil"

        if Self.verbose {
            os_log("\(self.t)🏃 SetCurrentScene: \(oldSceneName) -> \(sceneName)")
        }

        guard sceneNames.contains(sceneName) else {
            os_log(.error, "\(self.t)❌ 场景切换失败: 场景 \(sceneName) 不存在")
            throw PluginProviderError.sceneNotFound(sceneName: sceneName)
        }

        self.currentSceneName = sceneName
        repo.storeCurrentSceneName(sceneName)
    }

    /// 重置插件提供者
    ///
    /// 清空所有插件列表和当前激活的场景。
    /// 通常用于应用重置或重新初始化场景。
    func reset() {
        self.plugins = []
        self.currentSceneName = nil
    }

    /// 恢复上次激活的场景
    ///
    /// 从持久化存储中读取上次激活的场景名称，并尝试恢复该场景。
    /// 如果找不到上次的场景，则激活第一个可用的场景。
    ///
    /// ## 恢复逻辑
    /// 1. 尝试恢复存储的场景名称
    /// 2. 如果找不到，使用第一个可用场景
    /// 3. 如果都没有，记录错误日志
    ///
    /// - Throws: `PluginProviderError.sceneNotFound` 如果场景不存在
    @MainActor
    func restoreCurrent() throws {
        let savedSceneName = repo.getCurrentSceneName()

        if sceneNames.contains(savedSceneName) {
            try self.setCurrentScene(savedSceneName)
        } else if let firstScene = sceneNames.first {
            try self.setCurrentScene(firstScene)
        } else {
            os_log(.error, "\(self.t)⚠️⚠️⚠️ No scenes available")
        }
    }
    
    // MARK: - Plugin Registration Methods
    
    /// 注册一个插件实例
    /// - Parameter plugin: 要注册的插件实例
    private func register(_ plugin: any SuperPlugin) {
        let id = plugin.id

        // 检查 ID 是否已存在
        if usedIds.contains(id) {
            let pluginType = String(describing: type(of: plugin))
            os_log(.error, "\(Self.t)❌ Duplicate plugin id '\(id)' in \(pluginType)")
            assertionFailure("Duplicate plugin id: \(id)")
            return
        }

        // 标记该 ID 已使用
        usedIds.insert(id)
        registeredPlugins.append(plugin)

        // 调用插件的生命周期钩子
        if Self.verbose {
            os_log("\(Self.t)🔔 Calling onRegister() for \(plugin.id)")
        }
        plugin.onRegister()
    }
    
    /// 获取所有已注册的插件实例，按 order 排序
    /// - Returns: 排序后的插件实例数组
    private func getAllPlugins() -> [any SuperPlugin] {
        registeredPlugins.sorted { type(of: $0).order < type(of: $1).order }
    }
    
    /// 清空所有注册的插件
    private func clearRegisteredPlugins() {
        registeredPlugins.removeAll()
        usedIds.removeAll()
    }
    
    /// 已注册插件数量
    private var registeredCount: Int {
        registeredPlugins.count
    }

    /// 根据场景名称查找对应的插件
    /// - Parameter sceneName: 场景名称
    /// - Returns: 提供该场景的插件，如果不存在则返回 nil
    func plugin(for sceneName: String) -> (any SuperPlugin)? {
        plugins.first { plugin in
            plugin.addSceneItem() == sceneName
        }
    }
    
    /// 自动发现并注册所有插件
    /// 通过扫描 Objective-C runtime 中所有以 "Plugin" 结尾的类
    private func autoDiscoverAndRegisterPlugins() {
        // 清空已有注册（防止重复注册）
        clearRegisteredPlugins()
        
        var count: UInt32 = 0
        guard let classList = objc_copyClassList(&count) else {
            os_log(.error, "\(self.t)❌ Failed to get class list")
            return
        }
        defer { free(UnsafeMutableRawPointer(classList)) }
        
        let classes = UnsafeBufferPointer(start: classList, count: Int(count))
        
        // 临时存储发现的插件，用于排序
        var discoveredPlugins: [(plugin: any SuperPlugin, className: String, order: Int)] = []
        
        for i in 0 ..< classes.count {
            let cls: AnyClass = classes[i]
            let className = NSStringFromClass(cls)
            
            // 只检查 Cisum 命名空间下以 "Plugin" 结尾的类
            guard className.hasPrefix("Cisum."), className.hasSuffix("Plugin") else { continue }
            
            // 尝试通过 Objective-C Runtime 创建实例
            guard let instance = createActorInstance(cls: cls, className: className) as? any SuperPlugin else {
                if Self.verbose { os_log("\(self.t)⚠️ Failed to create instance for \(className)") }
                continue
            }
            
            // 获取插件类型
            let pluginType = type(of: instance)
            let pluginOrder = pluginType.order
            
            // 检查插件是否应该注册
            if !pluginType.shouldRegister {
                if Self.verbose { os_log("\(self.t)⏭️ Skipping plugin (shouldRegister=false): \(className)") }
                continue
            }
            
            // 添加到临时数组，稍后按 order 排序
            discoveredPlugins.append((instance, className, pluginOrder))
        }
        
        // 按 order 排序后注册
        discoveredPlugins.sort { $0.order < $1.order }
        
        for (plugin, className, order) in discoveredPlugins {
            register(plugin)
            if Self.verbose { os_log("\(self.t)🚀 #\(order) Registered: \(className)") }
        }
    }
    
    /// 创建 actor 实例的辅助函数
    /// 由于 actor 的特殊性，我们需要使用 Objective-C Runtime 来创建实例
    /// 注意：actor 的 init() 方法可能不能通过 Objective-C Runtime 直接调用
    /// 这里我们尝试使用 alloc + init 的方式
    private func createActorInstance(cls: AnyClass, className: String) -> AnyObject? {
        // 尝试获取 alloc 方法
        let allocSelector = NSSelectorFromString("alloc")
        guard let allocMethod = class_getClassMethod(cls, allocSelector) else {
            return nil
        }
        
        // 调用 alloc
        typealias AllocMethod = @convention(c) (AnyClass, Selector) -> AnyObject?
        let allocImpl = unsafeBitCast(method_getImplementation(allocMethod), to: AllocMethod.self)
        guard let instance = allocImpl(cls, allocSelector) else {
            return nil
        }
        
        // 尝试获取 init() 方法
        let initSelector = NSSelectorFromString("init")
        guard let initMethod = class_getInstanceMethod(cls, initSelector) else {
            return instance
        }
        
        // 调用 init
        typealias InitMethod = @convention(c) (AnyObject, Selector) -> AnyObject?
        let initImpl = unsafeBitCast(method_getImplementation(initMethod), to: InitMethod.self)
        
        return initImpl(instance, initSelector) ?? instance
    }

    /// 验证插件架构约束
    ///
    /// 强制执行架构规则：提供场景的插件必须同时提供海报视图。
    /// 如果违反规则，应用将停止运行，确保架构一致性。
    private func validatePluginArchitecture() {
        for plugin in plugins {
            let hasScene = plugin.addSceneItem() != nil
            let hasPoster = plugin.addPosterView() != nil

            if hasScene && !hasPoster {
                let pluginType = String(describing: type(of: plugin))
                let sceneName = plugin.addSceneItem() ?? "Unknown"
                let message = """
                ❌ 架构约束违规：插件 '\(pluginType)' 提供了场景 '\(sceneName)' 但未提供海报视图。

                架构规则要求：任何提供场景（addSceneItem）的插件必须同时提供海报视图（addPosterView）。

                请修改该插件，添加 addPosterView() 方法。
                """

                os_log(.fault, "\(Self.t)\(message)")
                fatalError(message)
            }
        }
    }
}

// MARK: - Event Handler

extension PluginProvider {
    /// 对所有插件执行异步操作
    ///
    /// 遍历所有已注册的插件，对每个插件执行指定的异步操作。
    /// 如果某个插件的操作失败，会捕获错误并记录日志，然后继续处理下一个插件。
    ///
    /// - Parameter operation: 要对每个插件执行的异步操作闭包
    func executePluginOperation(_ operation: @Sendable (SuperPlugin) async throws -> Void) async {
        for plugin in plugins {
            do {
                try await operation(plugin)
            } catch {
                os_log(.error, "\(self.t)Plugin operation failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Error

/// 插件提供者错误类型
///
/// 定义了插件管理过程中可能出现的错误情况。
enum PluginProviderError: Error, LocalizedError {
    /// 插件未找到
    ///
    /// 当根据 ID 查找插件失败时抛出此错误。
    ///
    /// - Parameter pluginId: 插件的唯一标识符
    case pluginNotFound(pluginId: String)

    /// 插件不提供场景
    ///
    /// 当尝试将不提供场景的插件设置为当前场景时抛出此错误。
    ///
    /// - Parameter pluginId: 插件的唯一标识符
    case pluginDoesNotProvideScene(pluginId: String)

    /// 场景未找到
    ///
    /// 当根据场景名称查找插件失败时抛出此错误。
    ///
    /// - Parameter sceneName: 场景名称
    case sceneNotFound(sceneName: String)

    /// 插件 ID 重复
    ///
    /// 当尝试注册具有重复 ID 的插件时抛出此错误。
    ///
    /// - Parameters:
    ///   - pluginId: 重复的插件 ID
    ///   - collection: 已存在的插件 ID 集合
    case duplicatePluginID(pluginId: String, collection: [String])

    /// 插件 ID 为空
    ///
    /// 当插件的 ID 为空字符串时抛出此错误。
    case pluginIDIsEmpty

    var errorDescription: String? {
        switch self {
        case let .pluginNotFound(pluginId):
            return "Plugin \(pluginId) not found"
        case let .pluginDoesNotProvideScene(pluginId):
            return "Plugin \(pluginId) does not provide a scene"
        case let .sceneNotFound(sceneName):
            return "Scene \(sceneName) not found"
        case let .duplicatePluginID(pluginId, collection):
            return "Plugin with ID \(pluginId) already exists in collection: \(collection)"
        case .pluginIDIsEmpty:
            return "Plugin has an empty ID"
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

#Preview("App - Demo") {
    ContentView()
        .inRootView()
        .showTabView()
        .inDemoMode()
        .withDebugBar()
}
