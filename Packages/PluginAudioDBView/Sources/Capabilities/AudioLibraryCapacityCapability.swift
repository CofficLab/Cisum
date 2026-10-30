import Foundation
import ProviderAudioLibrary

/// 仓库容量准入能力（视图插件侧）。
///
/// 内核 `AudioCapacityProviding` 的判定是 `async`（要读数据库计数），
/// 而写入入口需要在复制**之前**拿到结论。这个能力把「等判定」这件事
/// 收敛到一处，让调用方只表达意图。
@MainActor
public protocol AudioLibraryCapacityCapability: AnyObject, Sendable {
    /// 判定一批文件能否写入仓库。
    ///
    /// - Parameters:
    ///   - requestedCount: 请求写入的文件数量。
    ///   - reservedCount: 已被进行中写入操作占用的槽位数量。
    /// - Returns: 判定结果，含实际可写入的数量。
    func admit(requestedCount: Int, reservedCount: Int) async -> AudioCapacityAdmission

    /// 当前用户是否不受容量限制（付费用户）。
    var isCapacityUnlimited: Bool { get }

    /// 免费用户可持有的最大文件数量。
    var freeTierFileLimit: Int { get }
}

/// 将内核 `AudioCapacityProviding` 收窄为视图插件的容量能力。
///
/// ## 惰性解析
///
/// 数据层插件的 boot 顺序不确定，本插件的视图贡献可能早于
/// `AudioCapacityProviding` 注册。能力内部持**惰性解析闭包**而非快照
/// Provider：Provider 稍后就绪时能力自动生效。
@MainActor
final class AudioLibraryCapacityCapabilityAdapter: AudioLibraryCapacityCapability {
    private let resolve: @MainActor @Sendable () -> (any AudioCapacityProviding)?

    init(resolve: @escaping @MainActor @Sendable () -> (any AudioCapacityProviding)?) {
        self.resolve = resolve
    }

    func admit(requestedCount: Int, reservedCount: Int) async -> AudioCapacityAdmission {
        await resolve()?.admit(requestedCount: requestedCount, reservedCount: reservedCount) ?? .admitted
    }

    var isCapacityUnlimited: Bool {
        resolve()?.isCapacityUnlimited ?? true
    }

    var freeTierFileLimit: Int {
        resolve()?.freeTierFileLimit ?? AudioPluginInfo.maxAudioCount
    }
}
