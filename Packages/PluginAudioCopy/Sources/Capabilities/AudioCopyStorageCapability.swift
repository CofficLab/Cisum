import Foundation
import CisumProviderStorage

/// 复制任务的存储能力。
///
/// 提供插件专属数据目录，用于存放复制任务数据库。
/// 对齐 Lumi 规范：插件数据目录名 = 插件 ID。
@MainActor
protocol AudioCopyStorageCapability: AnyObject {
    /// 获取插件专属数据目录（会创建目录）。
    func pluginDataDirectory() -> URL?

    /// 解析插件专属数据目录路径（**不创建目录**）。
    ///
    /// 需要先判断目录是否存在（例如目录迁移）时必须用它：若先创建目录，
    /// 「新目录是否已存在」的判断将永远为真，迁移就永远不会执行。
    func pluginDataDirectoryPath() -> URL?
}

/// 存储能力适配器：惰性解析内核 StorageProviding。
///
/// 数据层插件的 boot 顺序不确定，复制视图贡献可能早于存储服务注册；
/// 惰性解析让 Provider 稍后就绪时能力自动生效。
@MainActor
final class AudioCopyStorageCapabilityAdapter: AudioCopyStorageCapability {
    /// 本插件的 id。目录名 = 插件 id，因此历史目录名的查询也以它为键。
    nonisolated static let pluginID = "com.coffic.cisum.plugin.copy"

    private let resolve: @MainActor @Sendable () -> (any StorageProviding)?

    init(resolve: @escaping @MainActor @Sendable () -> (any StorageProviding)?) {
        self.resolve = resolve
    }

    func pluginDataDirectory() -> URL? {
        resolve()?.pluginDataDirectory(for: Self.pluginID)
    }

    func pluginDataDirectoryPath() -> URL? {
        resolve()?.pluginDataDirectoryPath(for: Self.pluginID)
    }
}
