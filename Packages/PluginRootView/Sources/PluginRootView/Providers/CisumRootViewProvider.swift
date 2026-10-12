import KernelCore
import ProviderRootView
import SwiftUI

/// Uses LumiProviders' shared root-view state with Cisum's own player layout.
@MainActor
public final class CisumRootViewProvider: DefaultRootViewProviding {
    private weak var kernel: KernelCoreContainer?

    public init(kernel: KernelCoreContainer) {
        self.kernel = kernel
        super.init()
    }

    public override func makeRootView() -> AnyView {
        guard let kernel else { return AnyView(EmptyView()) }
        return AnyView(CisumRootOverlayHostView(provider: self, kernel: kernel))
    }
}
