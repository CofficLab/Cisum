import Foundation
import ProviderAudioLibrary
@testable import PluginAudioCopy

/// 容量准入能力替身：用可控的计数验证判定语义。
///
/// 判定规则的真值在数据层的闸门（`AudioCapacityProviding`），插件侧只
/// 消费结论。这个替身让「仓库已有多少」「进行中占多少」「是否付费」
/// 三个输入可被测试精确控制。
@MainActor
final class StubAudioCopyCapacity: AudioCopyCapacityCapability {
    /// 仓库里已有的文件数。
    var libraryCount: Int

    /// 进行中复制占用的槽位数（测试里由 `admit` 的 `reservedCount` 传入）。
    var pendingCopyTaskCount: Int

    /// 是否为付费用户（不受容量限制）。
    var isUnlimited: Bool

    /// 当前档位显示名。
    var tierDisplayName: String

    init(
        libraryCount: Int,
        pendingCopyTaskCount: Int = 0,
        isUnlimited: Bool = false,
        tierDisplayName: String = "Free version"
    ) {
        self.libraryCount = libraryCount
        self.pendingCopyTaskCount = pendingCopyTaskCount
        self.isUnlimited = isUnlimited
        self.tierDisplayName = tierDisplayName
    }

    func admit(requestedCount: Int, reservedCount: Int) async -> AudioCapacityAdmission {
        guard !isUnlimited else { return .admitted }
        guard requestedCount > 0 else { return .admitted }

        let occupied = libraryCount + max(0, reservedCount)
        let limit = AudioPluginInfo.maxAudioCount
        let remaining = max(0, limit - occupied)
        let allowed = min(requestedCount, remaining)

        if allowed == requestedCount { return .admitted }
        if allowed == 0 { return .rejected }
        return .partiallyAdmitted(allowedCount: allowed)
    }

    var isCapacityUnlimited: Bool { isUnlimited }
}
