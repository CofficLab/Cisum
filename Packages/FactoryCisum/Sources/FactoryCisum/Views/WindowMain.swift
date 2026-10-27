import LumiUI
import KernelCore
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
                    .accessibilityElement(children: .contain)
            } else if let initializationError {
                KernelErrorView(error: initializationError)
                    .accessibilityElement(children: .contain)
            } else if let kernel {
                #if os(iOS)
                // iOS 没有独立的设置窗口 Scene：设置页以 sheet 形式呈现，
                // 因此主视图要包进 `IOSSettingsAppShell`（由设置齿轮广播的
                // openSettings 通知触发）。macOS 走 `Window` + `openWindow`，
                // 不需要这层外壳。
                IOSSettingsAppShellHost(
                    kernel: kernel,
                    mainView: AnyView(
                        KernelRootView(kernel: kernel)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("cisum.kernel.ready")
                    )
                )
                #else
                KernelRootView(kernel: kernel)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("cisum.kernel.ready")
                #endif
            }
        }
        .appThemedAppearance()
        .environment(\.toastWindowID, AppBootstrap.mainWindowID)
#if os(macOS)
        .overlay {
            ThemeWindowAppearanceBridge().allowsHitTesting(false)
            MainWindowMinimumSizeBridge(
                minimumSize: CGSize(
                    width: AppResponsivePlayerLayoutMetrics.shared.minimumWindowSize.width,
                    height: AppResponsivePlayerLayoutMetrics.shared.minimumWindowSize.height
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
