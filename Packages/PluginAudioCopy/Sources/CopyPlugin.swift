import CisumUIComponents
import KernelCore
import ProviderDocsView
import ProviderAudioLibrary
import SwiftUI
import MagicKit

#if os(macOS)
    public actor CopyPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

        public static let shared = CopyPlugin()
        public static let metadata = PluginMetadata(
            displayName: String(localized: "Copy", bundle: .module),
            description: String(localized: String.LocalizationValue(AudioCopyPluginInfo.descriptionKey), bundle: .module),
            iconName: AudioCopyPluginInfo.iconName,
            order: 0,
        category: .tool,
        )

        nonisolated(unsafe) private weak var kernel: CisumKernel?


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        self.kernel = kernel
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { CopyPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { CopyPluginManualView() })
        }
    }

        @MainActor
        public func addStateView() -> AnyView? {
            configureService()
            return AudioCopyService.getStateView()
        }

        @MainActor
        public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
            configureService()
            return AudioCopyService.getRootView { content() }
        }

        @MainActor
        private func configureService() {
            AudioCopyService.configure(
                audioDiskProvider: {
                    self.kernel?.audioLibrary?.audioDisk
                },
                audioCountProvider: {
                    guard let library = self.kernel?.audioLibrary else {
                        return 0
                    }
                    return await library.totalCount()
                }
            )
        }
    }
#endif
