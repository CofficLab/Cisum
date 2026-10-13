import ProviderDocsView
import CisumProviderStorage
import KernelCore
import ProviderPlugin
import KitAppEvents
import CisumUIComponents
import LumiUI
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

    /// 本插件消费的能力 Adapter。ViewModel 以 `weak` 持有，故入口必须显式
    /// 强持有，否则能力会随装配调用返回而释放。
    nonisolated(unsafe) private var bookRootCapability: BookRootCapabilityAdapter?
    nonisolated(unsafe) private var bookStorageCapability: BookStorageCapabilityAdapter?
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
        let capability = BookRootCapabilityAdapter(books: bookProvider)
        bookRootCapability = capability
        let viewModel = BookRootViewModel(books: capability)
        // 观察者只在 init 期间使用能力安装订阅，之后仅依赖句柄；
        // 但为满足入口强持有的统一约定，能力同时被本插件持有。
        let storageCapability = BookStorageCapabilityAdapter(storage: storage)
        self.bookStorageCapability = storageCapability
        let observer = BookStorageObserver(storage: storageCapability, viewModel: viewModel)
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
        // 视图贡献可能早于数据层就绪：能力缺失时退化为「未就绪」错误态。
        let viewModel = BookRootViewModel(books: nil)
        rootViewModel = viewModel
        return viewModel
    }
}