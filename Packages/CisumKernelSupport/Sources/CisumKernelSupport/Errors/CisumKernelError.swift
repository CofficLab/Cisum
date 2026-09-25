import Foundation

/// CisumKernel 错误类型。
public enum CisumKernelError: Error, LocalizedError {
    /// 插件 ID 重复。
    case pluginAlreadyRegistered(id: String)

    /// 未找到插件。
    case pluginNotFound(id: String)
    case pluginNotConfigurable(id: String)

    /// 缺少必需服务。
    ///
    /// - Parameter services: 缺失的服务名称列表。
    case missingRequiredServices([String])

    /// 服务不可用。
    ///
    /// - Parameter service: 服务名称。
    case serviceNotAvailable(service: String)

    /// 插件启动/注册/就绪失败（由插件抛出的错误包装而来）。
    ///
    /// - Parameters:
    ///   - pluginID: 抛出错误的插件 ID，用于报错视图定位问题来源。
    ///   - message: 底层错误描述。
    case pluginFailed(pluginID: String, message: String)

    /// 场景未找到。
    ///
    /// - Parameter sceneName: 场景名称。
    case sceneNotFound(sceneName: String)

    /// 插件 ID 为空。
    case pluginIDIsEmpty

    /// 插件 ID 重复。
    ///
    /// - Parameters:
    ///   - pluginID: 重复的插件 ID。
    ///   - existing: 已存在的插件 ID 集合。
    case duplicatePluginID(pluginID: String, existing: [String])

    /// 播放器不处于可播放状态。
    case playbackNotReady

    /// 主题不合法或未找到。
    case invalidTheme(themeID: String)

    /// 存储路径无效。
    case invalidStoragePath(path: String)

    /// Provider 重复注册。
    ///
    /// 对齐 Lumi `KernelCore+Provider` 的语义：Provider 必须显式 `unregisterProvider`
    /// 之后才能被替换，禁止静默覆盖。这样能尽早暴露"onReady 替换 onBoot 实例"
    /// 这类隐性 bug（见 `ScenePlugin` 的 enablePersistence 重构）。
    ///
    /// - Parameters:
    ///   - type: 被重复注册的协议类型。
    ///   - owner: 原注册来源的插件 ID（由 `activePluginID` 在注册时捕获），未
    ///            知时为 `nil`。
    case providerAlreadyRegistered(type: Any.Type, owner: String?)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .pluginAlreadyRegistered(let id):
            return "Plugin '\(id)' is already registered"
        case .pluginNotFound(let id):
            return "Plugin '\(id)' not found"
        case .pluginNotConfigurable(let id):
            return "Plugin '\(id)' cannot be toggled by user"
        case .missingRequiredServices(let services):
            return "Missing required services: \(services.joined(separator: ", "))"
        case .serviceNotAvailable(let service):
            return "\(service) service is not available"
        case .pluginFailed(let pluginID, let message):
            return "\(message) (plugin: \(pluginID))"
        case .sceneNotFound(let sceneName):
            return "Scene '\(sceneName)' not found"
        case .pluginIDIsEmpty:
            return "Plugin has an empty ID"
        case .duplicatePluginID(let pluginID, _):
            return "Duplicate plugin ID: \(pluginID)"
        case .playbackNotReady:
            return "Playback manager is not ready — no playable asset loaded"
        case .invalidTheme(let themeID):
            return "Invalid or unknown theme: \(themeID)"
        case .invalidStoragePath(let path):
            return "Invalid storage path: \(path)"
        case .providerAlreadyRegistered(let type, let owner):
            let typeName = String(reflecting: type)
            let suffix = owner.map { " by plugin '\($0)'" } ?? ""
            return "Provider '\(typeName)' is already registered\(suffix); unregister it first"
        }
    }
}
