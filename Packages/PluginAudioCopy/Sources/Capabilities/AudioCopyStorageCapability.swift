import Foundation
import CisumProviderStorage

/// 复制任务的存储能力。
///
/// 提供插件专属数据目录，用于存放复制任务数据库。
/// 对齐 Lumi 规范：插件数据目录名 = 插件 ID。
@MainActor
protocol AudioCopyStorageCapability: AnyObject {
    /// 获取插件专属数据目录。
    func pluginDataDirectory() -> URL?
}

/// 存储能力适配器：惰性解析内核 StorageProviding。
///
/// 数据层插件的 boot 顺序不确定，复制视图贡献可能早于存储服务注册；
/// 惰性解析让 Provider 稍后就绪时能力自动生效。
@MainActor
final class AudioCopyStorageCapabilityAdapter: AudioCopyStorageCapability {
    private let resolve: @MainActor @Sendable () -> (any StorageProviding)?

    init(resolve: @escaping @MainActor @Sendable () -> (any StorageProviding)?) {
        self.resolve = resolve
    }

    func pluginDataDirectory() -> URL? {
        resolve()?.pluginDataDirectory(for: "CopyPlugin")
    }
}
