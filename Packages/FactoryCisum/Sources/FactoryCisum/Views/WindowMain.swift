import CisumUIComponents
import CisumKernelSupport
import SwiftUI

/// Factory 的主窗口启动视图。
///
/// 负责创建 Kernel，并在 Kernel 准备完成后显示 `KernelRootView`。
public struct WindowMain: View {
    @State private var kernel: KernelCoreContainer?
    @State private var initializationError: Error?
    @State private var isInitializing = true
    private let configuration: FactoryCisumConfiguration

    public init(configuration: FactoryCisumConfiguration) {
        self.configuration = configuration
    }

    public var body: some View {
        Group {
            if isInitializing {
                KernelLoadingView()
            } else if let initializationError {
                KernelErrorView(error: initializationError)
            } else if let kernel {
                KernelRootView(kernel: kernel)
            }
        }
        .appThemedAppearance()
#if os(macOS)
        .overlay {
            ThemeWindowAppearanceBridge().allowsHitTesting(false)
            MainWindowMinimumSizeBridge(
                minimumSize: CGSize(
                    width: CisumPlayerLayout.minimumWindowWidth,
                    height: CisumPlayerLayout.minimumWindowHeight
                )
            )
            .allowsHitTesting(false)
        }
#endif
        .task {
            await initializeKernel()
        }
    }

    private func initializeKernel() async {
        guard kernel == nil, initializationError == nil else { return }

        do {
            kernel = try await FactoryCisum.createMainKernel(configuration: configuration)
        } catch {
            initializationError = error
        }
        isInitializing = false
    }
}
