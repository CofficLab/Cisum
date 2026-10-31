import Foundation
import ProviderAudioLibrary
import Testing
@testable import ProviderAudioLibrary

/// 容量准入的判定结果是**所有写入入口的唯一真源**：
/// 拖放到主窗口、仓库视图的文件选择器、仓库视图的拖放都读它。
///
/// 因此它的边界语义必须精确——尤其「允许数量」不能超过请求数量，
/// 否则调用方会以为多放行了几个文件。
@Suite("仓库容量准入结果")
struct AudioCapacityAdmissionTests {
    @Test("全部放行时返回请求数量")
    func admittedAllowsRequestedCount() {
        #expect(AudioCapacityAdmission.admitted.allowedCount(requestedCount: 5) == 5)
        #expect(AudioCapacityAdmission.admitted.allowedCount(requestedCount: 0) == 0)
    }

    @Test("部分放行时返回允许数量")
    func partiallyAdmittedReturnsAllowedCount() {
        #expect(AudioCapacityAdmission.partiallyAdmitted(allowedCount: 3).allowedCount(requestedCount: 10) == 3)
    }

    @Test("部分放行的允许数量不会超过请求数量")
    func partiallyAdmittedIsClampedToRequestedCount() {
        // 允许数大于请求数是「不该发生」的状态：必须收敛到请求数，
        // 否则调用方会以为多放行了几���文件。
        #expect(AudioCapacityAdmission.partiallyAdmitted(allowedCount: 10).allowedCount(requestedCount: 3) == 3)
    }

    @Test("全部挡住时放行 0 个")
    func rejectedAllowsNothing() {
        #expect(AudioCapacityAdmission.rejected.allowedCount(requestedCount: 10) == 0)
        #expect(AudioCapacityAdmission.rejected.allowedCount(requestedCount: 0) == 0)
    }

    @Test("全部放行不构成拒绝")
    func admittedDoesNotReject() {
        #expect(AudioCapacityAdmission.admitted.didReject == false)
    }

    @Test("部分放行构成拒绝")
    func partiallyAdmittedDoesReject() {
        #expect(AudioCapacityAdmission.partiallyAdmitted(allowedCount: 3).didReject)
    }

    @Test("全部挡住构成拒绝")
    func rejectedDoesReject() {
        #expect(AudioCapacityAdmission.rejected.didReject)
    }

    @Test("请求 0 个文件时全部放行")
    func zeroRequestIsAdmitted() {
        // 空请求不应被误判成「撞限」——那会让用户看到毫无意义的付费提示。
        #expect(AudioCapacityAdmission.admitted.allowedCount(requestedCount: 0) == 0)
        #expect(AudioCapacityAdmission.admitted.didReject == false)
    }

    @Test("三种判定结果互不相同")
    func resultsAreDistinct() {
        #expect(AudioCapacityAdmission.admitted != AudioCapacityAdmission.rejected)
        #expect(AudioCapacityAdmission.admitted != AudioCapacityAdmission.partiallyAdmitted(allowedCount: 0))
        #expect(AudioCapacityAdmission.partiallyAdmitted(allowedCount: 1) != AudioCapacityAdmission.partiallyAdmitted(allowedCount: 2))
    }
}

// MARK: - 默认实现（能力缺失时的降级）

/// 容量能力缺失时默认「不限容量」——能力缺失是装配问题，
/// 不该让用户的文件凭空进不去。
@Suite("容量能力的默认实现")
@MainActor
struct AudioCapacityProvidingDefaultsTests {
    private final class DefaultCapacityProvider: AudioCapacityProviding {}

    @Test("默认不限容量")
    func defaultsToUnlimited() {
        let provider = DefaultCapacityProvider()
        #expect(provider.isCapacityUnlimited)
    }

    @Test("默认档位为免费版")
    func defaultsToFreeTier() {
        let provider = DefaultCapacityProvider()
        #expect(provider.tierDisplayName == "Free version")
    }

    @Test("默认放行全部")
    func defaultsToAdmitted() async {
        let provider = DefaultCapacityProvider()
        let admission = await provider.admit(requestedCount: 1000, reservedCount: 0)

        #expect(admission == .admitted)
        #expect(admission.didReject == false)
    }

    @Test("默认免费额度取自插件信息")
    func defaultLimitMatchesPluginInfo() {
        let provider = DefaultCapacityProvider()
        #expect(provider.freeTierFileLimit == AudioPluginInfo.maxAudioCount)
    }
}
