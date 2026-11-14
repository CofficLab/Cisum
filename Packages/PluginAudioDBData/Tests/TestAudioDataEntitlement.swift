import Foundation
@testable import PluginAudioDBData

/// 测试用的权益替身：显式控制「是否受容量限制」。
///
/// 权益必须由入口显式注入（生产环境经能力适配器从商店 Provider 解析），
/// 不能有「默认无限额」的兜底——那会让商店 Provider 未就绪时
/// 免费用户直接绕过上限。
@MainActor
final class TestAudioDataEntitlement: AudioDataEntitlementCapability {
    var isCapacityLimited: Bool
    var tierDisplayName: String

    init(isCapacityLimited: Bool = true, tierDisplayName: String = "Free version") {
        self.isCapacityLimited = isCapacityLimited
        self.tierDisplayName = tierDisplayName
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioDataEntitlementEvent) -> Void
    ) -> any AudioDataEntitlementObserverHandle {
        TestAudioDataEntitlementHandle()
    }
}

/// 空句柄：测试替身不派发事件。
@MainActor
final class TestAudioDataEntitlementHandle: AudioDataEntitlementObserverHandle {
    func cancel() {}
}
