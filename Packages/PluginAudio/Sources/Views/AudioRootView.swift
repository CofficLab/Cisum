import Foundation
import CisumUIComponents
import SwiftUI

struct AudioRootErrorPresentation: Equatable {
    let title: String
    let message: String
    let detail: String?

    static func make(error: AudioRootError?) -> AudioRootErrorPresentation {
        guard let error else {
            return AudioRootErrorPresentation(
                title: String(localized: "Audio Library Initialization Failed", bundle: .module),
                message: String(localized: "Try reopening the app or checking media library settings.", bundle: .module),
                detail: nil
            )
        }

        switch error {
        case .storageMissing:
            return AudioRootErrorPresentation(
                title: String(localized: "Storage Location Not Set", bundle: .module),
                message: String(localized: "Set the media library storage location first.", bundle: .module),
                detail: nil
            )
        case .initialization(let reason):
            return AudioRootErrorPresentation(
                title: String(localized: "Audio Library Initialization Failed", bundle: .module),
                message: String(localized: "Try reopening the app or checking media library settings.", bundle: .module),
                detail: reason
            )
        }
    }
}

public struct AudioRootView<Content>: View where Content: View {
    @ObservedObject var viewModel: AudioRootViewModel
    private var content: Content

    init(viewModel: AudioRootViewModel, @ViewBuilder content: () -> Content) {
        self.viewModel = viewModel
        self.content = content()
    }

    public var body: some View {
        Group {
            if viewModel.isInitializing {
                ProgressView {
                    Text("Initializing...", bundle: .module)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.error != nil {
                storageErrorView
            } else if viewModel.error == nil {
                ZStack {
                    content
                }
                .onDisappear(perform: handleOnDisappear)
            } else {
                storageErrorView
            }
        }
        .task {
            viewModel.reloadContainer()
        }
        // 存储位置变化（由 AudioStorageObserver 驱动）时弹全局 toast；
        // View 只做 UI 表现，不再直接订阅存储通知。
        .onChange(of: viewModel.storageLocationDidChangeNotice) { _, _ in
            alert_info(String(localized: "Storage location has changed", bundle: .module))
        }
    }

    // MARK: - Error View

    private var storageErrorView: some View {
        let presentation = AudioRootErrorPresentation.make(error: viewModel.error)

        return VStack(spacing: 20) {
            Spacer()

            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text(presentation.title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text(presentation.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let detail = presentation.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Event Handler

extension AudioRootView {
    /// 处理视图消失事件。
    ///
    /// 当视图从屏幕上消失时触发，用于清理资源。
    func handleOnDisappear() {
        // 容器重建与存储变化监听由入口持有的 ViewModel + Observer 负责，
        // View 无需在此清理外部订阅。
    }
}
