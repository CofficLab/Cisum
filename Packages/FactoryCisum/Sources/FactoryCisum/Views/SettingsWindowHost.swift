import KernelCore
import MagicKit
import ProviderSettings
import PluginToast
import SwiftUI

/// Factory 的设置窗口接线视图。
///
/// 负责创建主内核，并在内核就绪后把插件设置 Provider 注入 `ProviderSettings.SettingsWindow`。
/// 设置窗口 UI 本身不感知内核/工厂，与主窗口共享同一内核实例。
public struct SettingsWindowHost: View {
    @State private var kernel: CisumKernel?
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
                let settings = ProviderSettings.SettingsWindow(
                    settings: kernel.plugin
                )
                if let provider = kernel.toast as? ToastProvider {
                    ToastOverlay(content: settings, center: provider)
                } else {
                    settings
                }
            }
        }
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
