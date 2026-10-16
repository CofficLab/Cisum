import CisumProviderStorage
import Foundation
import Testing
@testable import PluginAudioDBView

/// 首启引导期间，音频库不可用**不得**弹出通用仓库错误弹窗。
///
/// 复现的缺陷：`ToastOverlay` 的 `ErrorNoticeOverlay` 是带
/// `Color.black.opacity(0.22)` 全屏遮罩的模态层，它盖在首启引导之上并吞掉
/// 所有鼠标命中，于是「继续」按钮点不动，引导永远无法关闭。
///
/// 这里锁住判定规则：只有**已配置存储**时，仓库不可用才算真实故障。
@MainActor
@Test func repositoryUnavailableStaysSilentDuringFirstRunOnboarding() {
    #expect(!AudioRepositoryUnavailablePolicy.shouldPresentErrorNotice(
        hasUsableStorageLocation: false,
        isRepositoryAvailable: false
    ), "首启尚未配置存储位置时不得弹出仓库错误弹窗")
}

@Test func repositoryUnavailableIsReportedOnceStorageIsConfigured() {
    #expect(AudioRepositoryUnavailablePolicy.shouldPresentErrorNotice(
        hasUsableStorageLocation: true,
        isRepositoryAvailable: false
    ), "已配置存储却打不开仓库属于真实故障，必须提示")
}

@Test func availableRepositoryNeverReportsAnError() {
    #expect(!AudioRepositoryUnavailablePolicy.shouldPresentErrorNotice(
        hasUsableStorageLocation: true,
        isRepositoryAvailable: true
    ))
    #expect(!AudioRepositoryUnavailablePolicy.shouldPresentErrorNotice(
        hasUsableStorageLocation: false,
        isRepositoryAvailable: true
    ))
}

/// 存储 Provider 缺失时退化为「未配置」，即保持静默——
/// 引导层不得因此误判出一次仓库故障。
@MainActor
@Test func missingStorageProviderDegradesToUnconfigured() {
    let capability = AudioLibraryStorageCapabilityAdapter(storage: nil)
    #expect(!capability.hasUsableStorageLocation)
    #expect(!AudioRepositoryUnavailablePolicy.shouldPresentErrorNotice(
        hasUsableStorageLocation: capability.hasUsableStorageLocation,
        isRepositoryAvailable: false
    ))
}
