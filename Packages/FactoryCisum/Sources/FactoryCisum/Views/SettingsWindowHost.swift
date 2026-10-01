import ProviderToast
import KernelCore
import ProviderSettingView
import MagicKit
import PluginToast
import SwiftUI

/// Factory 的设置窗口接线视图。
///
/// 负责创建主内核，并在内核就绪后渲染远程设置外壳（PluginSettingView 插件
/// 提供的 `SettingViewProviding.makeSettingView()`，AppSettingsSidebarShell
/// 双栏布局）。设置窗口 UI 本身不感知内核/工厂，与主窗口共享同一内核实例。
public struct SettingsWindowHost: View {
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
                let toast = kernel.resolveProvider((any ToastProviding).self)
                let settings = kernel.resolveProvider((any SettingViewProviding).self)
                    .map { AnyView($0.makeSettingView().environment(\.toastProviding, toast)) }
                    ?? AnyView(EmptyView())
                if let center = toast as? ToastCenter {
                    ToastOverlay(content: settings, center: center)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("cisum.settings.ready")
                } else {
                    settings
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("cisum.settings.ready")
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
