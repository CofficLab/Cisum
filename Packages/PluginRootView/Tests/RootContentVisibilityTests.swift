import CoreGraphics
import Foundation
import ProviderAudioLibrary
import ProviderPlayback
import ProviderScene
import SwiftUI
import Testing
@testable import PluginRootView

/// 复现并锁定 p4.4.3 iOS「打开后音乐库被隐藏、只剩浮在中央的空播放器」的根因：
/// `RootLayoutView.handleGeometryChange` 里的「窗口变矮就收起副栏」规则本是
/// macOS 桌面行为，却未做平台隔离，导致 iOS 启动/旋转期间根视图瞬时上报的小高度
/// 把内容区永久收起（且无自动恢复路径）。
///
/// 判定被抽成纯函数 `RootContentVisibility.shouldHideContentView(isMacOS:newHeight:dropThreshold:)`，
/// 通过注入平台参数，在本机（macOS CI）即可同时覆盖 iOS / macOS 两条分支。
struct RootContentVisibilityTests {
    private let threshold: CGFloat = 270

    // MARK: - iOS：几何变化绝不自动收起内容区

    @Test("iOS 上极短的瞬时高度不得收起内容区（复现 p4.4.3 空播放器 bug）")
    func iosNeverHidesContentViewOnShortGeometry() {
        #expect(!RootContentVisibility.shouldHideContentView(
            isMacOS: false, newHeight: 0, dropThreshold: threshold
        ))
        #expect(!RootContentVisibility.shouldHideContentView(
            isMacOS: false, newHeight: 100, dropThreshold: threshold
        ))
        // 恰好在旧阈值边界上，iOS 同样不得收起。
        #expect(!RootContentVisibility.shouldHideContentView(
            isMacOS: false, newHeight: threshold, dropThreshold: threshold
        ))
    }

    @Test("iOS 上正常屏幕高度同样保持内容区可见")
    func iosKeepsContentViewAtRegularHeights() {
        #expect(!RootContentVisibility.shouldHideContentView(
            isMacOS: false, newHeight: 844, dropThreshold: threshold
        ))
    }

    // MARK: - macOS：保留既有的「窗口拉矮即收起副栏」响应式行为

    @Test("macOS 上高度低于或等于阈值时收起内容区")
    func macOSHidesContentViewAtOrBelowThreshold() {
        #expect(RootContentVisibility.shouldHideContentView(
            isMacOS: true, newHeight: 200, dropThreshold: threshold
        ))
        #expect(RootContentVisibility.shouldHideContentView(
            isMacOS: true, newHeight: threshold, dropThreshold: threshold
        ))
    }

    @Test("macOS 上高度高于阈值时保持内容区可见")
    func macOSKeepsContentViewAboveThreshold() {
        #expect(!RootContentVisibility.shouldHideContentView(
            isMacOS: true, newHeight: threshold + 1, dropThreshold: threshold
        ))
        #expect(!RootContentVisibility.shouldHideContentView(
            isMacOS: true, newHeight: 900, dropThreshold: threshold
        ))
    }
}

/// 播放环境能力替身：只实现根布局消费的三项快照 + 一条事件回调。
@MainActor
private final class EnvironmentStub: RootEnvironmentCapability {
    var currentURL: URL?
    var currentScene: AppScene?
    var repositoryScanState: AudioRepositoryScanState = .unknown

    private var callback: ((RootEnvironmentEvent) -> Void)?

    init(
        currentURL: URL? = nil,
        currentScene: AppScene? = .music,
        repositoryScanState: AudioRepositoryScanState = .unknown
    ) {
        self.currentURL = currentURL
        self.currentScene = currentScene
        self.repositoryScanState = repositoryScanState
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (RootEnvironmentEvent) -> Void
    ) -> any RootEnvironmentObserverHandle {
        self.callback = callback
        return Handle { [weak self] in self?.callback = nil }
    }

    func send(_ event: RootEnvironmentEvent) {
        callback?(event)
    }

    private final class Handle: RootEnvironmentObserverHandle {
        private let onCancel: () -> Void
        init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
        func cancel() { onCancel() }
    }
}

/// 贡献能力替身：根布局不消费其内容，只为满足协议。
@MainActor
private final class ContributionStub: RootContributionCapability {
    func getToolBarButtons() -> [(id: String, view: AnyView)] { [] }
    func getStatusViews() -> [AnyView] { [] }

    @discardableResult
    func addObserver(
        _ callback: @escaping (RootContributionEvent) -> Void
    ) -> any RootContributionObserverHandle { ContributionHandle() }
}

/// 贡献能力的事件枚举与句柄在此不需要真实实现。
private final class ContributionHandle: RootContributionObserverHandle {
    func cancel() {}
}

/// 根布局的播放器呈现态（控制区高度）由播放/场景/仓库事件驱动。
///
/// 本组用例锁定「仓库有歌但没有当前曲目」这一态的布局判定：
/// 控制区必须保持展开高度，否则占位内容渲染了也没有空间可放。
@MainActor
struct RootLayoutHeroPresentingTests {
    private func makeViewModel() -> RootLayoutViewModel {
        RootLayoutViewModel(contributions: ContributionStub())
    }

    @Test("有当前曲目时控制区保持展开")
    func keepsExpandedHeightWhenTrackIsSelected() {
        let viewModel = makeViewModel()
        let environment = EnvironmentStub(
            currentURL: URL(fileURLWithPath: "/library/track.mp3"),
            repositoryScanState: .nonEmpty
        )
        viewModel.attach(environment: environment)

        #expect(viewModel.isPlaybackHeroPresenting)
    }

    @Test("仓库非空但无当前曲目时控制区仍保持展开（idle 占位需要空间）")
    func keepsExpandedHeightForIdlePlaceholder() {
        let viewModel = makeViewModel()
        let environment = EnvironmentStub(
            currentURL: nil,
            repositoryScanState: .nonEmpty
        )
        viewModel.attach(environment: environment)

        #expect(
            viewModel.isPlaybackHeroPresenting,
            "idle 占位需要高度，否则占位渲染了也没有空间"
        )
    }

    @Test("仓库扫描结论未知时不占用展开高度（避免启动瞬间抢跑）")
    func collapsesWhileScanConclusionIsUnknown() {
        let viewModel = makeViewModel()
        let environment = EnvironmentStub(
            currentURL: nil,
            repositoryScanState: .unknown
        )
        viewModel.attach(environment: environment)

        #expect(!viewModel.isPlaybackHeroPresenting)
    }

    @Test("仓库为空且无当前曲目时收起（该区域归空仓库引导管）")
    func collapsesForEmptyRepositoryWithoutTrack() {
        let viewModel = makeViewModel()
        let environment = EnvironmentStub(
            currentURL: nil,
            repositoryScanState: .empty
        )
        viewModel.attach(environment: environment)

        #expect(!viewModel.isPlaybackHeroPresenting)
    }

    @Test("非音乐场景下不展开")
    func collapsesOutsideMusicScene() {
        let viewModel = makeViewModel()
        let environment = EnvironmentStub(
            currentURL: nil,
            currentScene: .audiobooks,
            repositoryScanState: .nonEmpty
        )
        viewModel.attach(environment: environment)

        #expect(!viewModel.isPlaybackHeroPresenting)
    }

    @Test("仓库转为非空后，idle 占位接管并保持展开")
    func expandsWhenRepositoryBecomesNonEmpty() {
        let viewModel = makeViewModel()
        let environment = EnvironmentStub(
            currentURL: nil,
            repositoryScanState: .empty
        )
        viewModel.attach(environment: environment)
        #expect(!viewModel.isPlaybackHeroPresenting)

        environment.send(.repositoryNonEmpty)
        #expect(viewModel.isPlaybackHeroPresenting)

        // 选中曲目后仍是展开态（真实封面接管）。
        environment.send(.assetChanged(URL(fileURLWithPath: "/library/track.mp3")))
        #expect(viewModel.isPlaybackHeroPresenting)
    }
}
