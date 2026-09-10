import Combine
import SwiftUI
import MagicKit

    /// `RootLayoutView` 的状态容器：订阅 `DefaultRootViewProvider` 的
/// `RootViewProvidingEvent` 监听机制，把各区域注入视图同步为可观察状态。
///
/// 取代原 `@ObservedObject provider`（ObservableObject + @Published）的直接观察，
/// 使 Provider 本身不依赖 `ObservableObject`。
@MainActor
final class RootLayoutViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var controlView: AnyView?
    @Published private(set) var contentView: AnyView?
    @Published private(set) var statusView: AnyView?
    @Published private(set) var toolbarContent: AnyView?
    @Published private(set) var isContentViewVisible: Bool

    private var handle: (any RootViewProvidingObserverHandle)?

    init(provider: DefaultRootViewProvider) {
        controlView = provider.controlView
        contentView = provider.contentView
        statusView = provider.statusView
        toolbarContent = provider.toolbarContent
        isContentViewVisible = provider.isContentViewVisible

        handle = provider.addObserver { [weak self] event in
            switch event {
            case .controlViewChanged: self?.controlView = provider.controlView
            case .contentViewChanged: self?.contentView = provider.contentView
            case .statusViewChanged: self?.statusView = provider.statusView
            case .toolbarContentChanged: self?.toolbarContent = provider.toolbarContent
            case .contentViewVisibilityChanged: self?.isContentViewVisible = provider.isContentViewVisible
            case .overlaysChanged: break
            }
        }
    }
}
