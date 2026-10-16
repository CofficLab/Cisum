import SwiftUI

/// First-run storage setup gate. It observes the storage contract directly so
/// the overlay disappears as soon as the user commits a usable location.
///
/// 引导层只是覆盖在根视图之外的 overlay，**无法**取消内层根布局已经声明的
/// `.toolbar` —— 工具栏是真实控件而非被遮挡的图层。因此展示期间必须经由
/// 根视图契约显式抑制工具栏，引导结束（或 overlay 消失）时再恢复。
@MainActor
struct WelcomeStorageSetupOverlay: View {
    @StateObject private var viewModel: WelcomeStorageSetupViewModel
    private let content: AnyView

    init(
        storage: any WelcomeStorageCapability,
        chrome: any WelcomeRootChromeCapability,
        content: AnyView
    ) {
        _viewModel = StateObject(wrappedValue: WelcomeStorageSetupViewModel(storage: storage, chrome: chrome))
        self.content = content
    }

    var body: some View {
        ZStack {
            content

            if viewModel.isSetupRequired {
                WelcomePluginGuideView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.regularMaterial)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("cisum.welcome.storage.setup")
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSetupRequired)
        .onDisappear { viewModel.restoreChromeIfNeeded() }
    }
}

@MainActor
private final class WelcomeStorageSetupViewModel: ObservableObject {
    @Published private(set) var isSetupRequired: Bool

    /// 存储能力（Capabilities 目录收窄）。
    ///
    /// **强持有**：本容器是 StateObject 持有的唯一宿主，能力内部对 Provider
    /// 为 `weak`，强持有能力不会延长存储 Provider 的生命周期。
    private let storage: any WelcomeStorageCapability

    /// 根视图外观能力（Capabilities 目录收窄），用于抑制引导期的工具栏。
    private let chrome: any WelcomeRootChromeCapability

    private var storageObserver: (any WelcomeStorageObserverHandle)?

    init(storage: any WelcomeStorageCapability, chrome: any WelcomeRootChromeCapability) {
        self.storage = storage
        self.chrome = chrome
        isSetupRequired = !storage.hasUsableStorageLocation
        // init 早于 body 求值，先把工具栏状态落定，避免首帧闪现工具栏。
        chrome.setToolbarHidden(isSetupRequired)
        storageObserver = storage.addObserver { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        let required = !storage.hasUsableStorageLocation
        guard required != isSetupRequired else { return }
        isSetupRequired = required
        chrome.setToolbarHidden(required)
    }

    /// overlay 整体消失（插件卸载 / 根视图重建）时兜底恢复工具栏，
    /// 否则引导不再需要时工具栏会一直处于隐藏态。
    func restoreChromeIfNeeded() {
        chrome.setToolbarHidden(false)
    }
}
