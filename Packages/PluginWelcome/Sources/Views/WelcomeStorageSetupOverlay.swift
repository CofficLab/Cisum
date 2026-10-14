import SwiftUI

/// First-run storage setup gate. It observes the storage contract directly so
/// the overlay disappears as soon as the user commits a usable location.
@MainActor
struct WelcomeStorageSetupOverlay: View {
    @StateObject private var viewModel: WelcomeStorageSetupViewModel
    private let content: AnyView

    init(storage: any WelcomeStorageCapability, content: AnyView) {
        _viewModel = StateObject(wrappedValue: WelcomeStorageSetupViewModel(storage: storage))
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
    private var storageObserver: (any WelcomeStorageObserverHandle)?

    init(storage: any WelcomeStorageCapability) {
        self.storage = storage
        isSetupRequired = !storage.hasUsableStorageLocation
        storageObserver = storage.addObserver { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        isSetupRequired = !storage.hasUsableStorageLocation
    }
}
