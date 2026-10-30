import KernelCore
import ProviderRootView
import SwiftUI

/// Observes overlay contributions and rebuilds their wrapper chain.
@MainActor
struct RootOverlayHostView: View {
    @ObservedObject var provider: RootViewProvider
    let kernel: KernelCoreContainer
    @State private var revision = 0
    @State private var observer: (any RootViewObserverHandle)?

    var body: some View {
        var root = AnyView(RootLayoutView(provider: provider, kernel: kernel))
        for overlay in provider.overlays {
            root = overlay.wrap(root)
        }
        return root
            .id(revision)
            .onAppear {
                guard observer == nil else { return }
                observer = provider.addRootViewObserver { event in
                    guard case .overlaysChanged = event else { return }
                    revision += 1
                }
            }
            .onDisappear {
                observer?.cancel()
                observer = nil
            }
    }
}
