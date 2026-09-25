import ProviderDocsView
import ProviderStorage
import CisumKernelSupport
import CisumUIComponents
import ProviderBook
import Foundation
import OSLog
import SwiftUI
import MagicKit

@MainActor
public final class BookPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: BookPlugin.self)

    nonisolated static let verbose = false

    public static let shared = BookPlugin()
    public let order = 1
    public let iconName = BookPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: BookPlugin.self),
        name: BookPluginInfo.title,
        description: BookPluginInfo.description,
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )

    nonisolated(unsafe) private var rootViewModel: BookRootViewModel?
    nonisolated(unsafe) private var rootObserver: BookStorageObserver?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if Self.verbose { os_log("\(Self.t)🔌 onRegister") }
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { BookPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { BookPluginManualView() })
        }
    }

    public static let keyOfCurrentBookURL = BookPluginInfo.keyOfCurrentBookURL
    public static let keyOfCurrentBookTime = BookPluginInfo.keyOfCurrentBookTime
    public static let dirName = BookPluginInfo.dirName
    public static let supportedExtensions = BookPluginInfo.supportedExtensions

    /// OnReady 阶段解析数据 Provider，并安装根 ViewModel + Observer。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)🟢 onReady") }
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else {
            os_log(.error, "\(Self.t)❌ onReady: storage 服务不可用")
            return
        }
        guard let bookProvider = kernel.resolveProvider(BookDatabaseProviding.self) else {
            os_log(.error, "\(Self.t)❌ onReady: book data Provider 不可用")
            return
        }
        installRootState(storage: storage, bookProvider: bookProvider)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)✅ onEnable") }
        if let storage = kernel.resolveProvider((any StorageProviding).self),
           let bookProvider = kernel.resolveProvider(BookDatabaseProviding.self) {
            installRootState(storage: storage, bookProvider: bookProvider)
        }
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)⏹️ onDisable") }
        teardownRootState()
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)🛑 onShutdown") }
        teardownRootState()
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        let viewModel = resolveRootViewModel()
        if Self.verbose { os_log("\(Self.t)📺 addRootView") }
        return AnyView(BookRootView(viewModel: viewModel, content: content))
    }

    // MARK: - State assembly

    @MainActor
    private func installRootState(
        storage: any StorageProviding,
        bookProvider: any BookDatabaseProviding
    ) {
        guard rootViewModel == nil else { return }
        if Self.verbose { os_log("\(Self.t)🔧 installRootState") }
        let viewModel = BookRootViewModel(bookProvider: bookProvider)
        let observer = BookStorageObserver(storage: storage, viewModel: viewModel)
        rootViewModel = viewModel
        rootObserver = observer
    }

    @MainActor
    private func teardownRootState() {
        if Self.verbose { os_log("\(Self.t)🧹 teardownRootState") }
        rootObserver?.cancel()
        rootObserver = nil
        rootViewModel = nil
    }

    @MainActor
    private func resolveRootViewModel() -> BookRootViewModel {
        if let rootViewModel {
            return rootViewModel
        }
        let viewModel = BookRootViewModel(
            bookProvider: nil
        )
        rootViewModel = viewModel
        return viewModel
    }
}