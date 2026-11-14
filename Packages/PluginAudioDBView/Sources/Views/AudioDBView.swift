import MagicKit
import LumiUI
import Foundation
import KitAudioRepositoryImport
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import ProviderAudioLibrary
import ProviderToast

// NSItemProvider is thread-safe by design but not yet marked Sendable by Apple.
extension NSItemProvider: @retroactive @unchecked Sendable {}

@MainActor
public struct AudioDBView: View, SuperLog, SuperThread, SuperEvent {
    public nonisolated static let emoji = "🐘"
    public nonisolated static let verbose = false

    @ObservedObject private var dbViewModel: AudioDBViewModel
    private let listViewModel: AudioListViewModel
    private let dependencies: AudioDBDependencies
    /// 导入控制器：拖放与文件选择器共用同一套复制 / 同步逻辑。
    @ObservedObject private var importer: AudioRepositoryImporter
    @LumiTheme private var appTheme
    private let isDemoMode: Bool

    /// 文件选择器的呈现状态由当前 SwiftUI subtree 持有；仅写入外部 provider
    /// Binding 不会使此视图失效，导致点击导入后选择器不呈现。
    @State private var isPresentingImporter = false

    private var viewDependencies: AudioDBDependencies {
        AudioDBDependencies(
            library: dependencies.library,
            audioDisk: dependencies.audioDisk,
            audioDiagnostics: dependencies.audioDiagnostics,
            supportedExtensions: dependencies.supportedExtensions,
            isDesktop: dependencies.isDesktop,
            isNotDesktop: dependencies.isNotDesktop,
            showDBView: dependencies.showDBView,
            isImporting: $isPresentingImporter
        )
    }

    init(
        isDemoMode: Bool,
        listViewModel: AudioListViewModel,
        dbViewModel: AudioDBViewModel,
        dependencies: AudioDBDependencies,
        importer: AudioRepositoryImporter
    ) {
        self.isDemoMode = isDemoMode
        self.listViewModel = listViewModel
        self._dbViewModel = ObservedObject(wrappedValue: dbViewModel)
        self.dependencies = dependencies
        self._importer = ObservedObject(wrappedValue: importer)
    }

    public var body: some View {
        if Self.verbose {
            os_log("\(self.t)📺 Rendering")
        }

        return Group {
            if isDemoMode {
                EmptyView()
            } else {
                AudioList(
                    viewModel: listViewModel,
                    dependencies: viewDependencies,
                    isDropping: importer.isDropping
                )
            }
        }
        .overlay(alignment: .center) {
            if dbViewModel.isSorting {
                AudioDBTips(
                    dependencies: viewDependencies,
                    variant: .sorting,
                    sortingMessage: dbViewModel.sortMode.description
                )
                    .transition(.opacity)
            }
        }
        .frame(maxHeight: .infinity)
        .background(appTheme.background.ignoresSafeArea())
        .fileImporter(
            isPresented: $isPresentingImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true,
            onCompletion: importer.handleFileImport
        )
        .onChange(of: isPresentingImporter) { _, isImporting in
            dependencies.isImporting.wrappedValue = isImporting
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $importer.isDropping, perform: importer.handleDrop)
    }
}

// MARK: - Action

extension AudioDBView {
    // MARK: - 导入机械流程（实现下沉在 KitAudioRepositoryImport）

    /// 逐个复制文件到仓库目录；中途失败时回滚已复制的文件。
    ///
    /// 机械实现见 `KitAudioRepositoryImport`；本插件保留同名入口，
    /// 让视图侧与既有测试的调用点保持不变。
    nonisolated static func copyFilesInBackground(_ urls: [URL], to storageRoot: URL) async throws -> [URL] {
        try await AudioRepositoryImportService.copyFilesInBackground(urls, to: storageRoot)
    }

    /// 删除已复制的文件（回滚用）。
    nonisolated static func cleanUpCopiedFiles(_ urls: [URL]) {
        AudioRepositoryImportService.cleanUpCopiedFiles(urls)
    }

    /// 过滤出可导入的文件：排除文件夹、不受支持的扩展名与重复项。
    nonisolated static func supportedImportURLs(from urls: [URL], supportedExtensions: [String]) -> [URL] {
        AudioRepositoryImportService.supportedImportURLs(from: urls, supportedExtensions: supportedExtensions)
    }

    /// 两个 URL 是否指向同一份文件。
    nonisolated static func representsSameImportSource(_ lhs: URL, _ rhs: URL) -> Bool {
        AudioRepositoryFileIdentity.representsSameFile(lhs, rhs)
    }

    /// 文件的规范身份（用于去重）。
    nonisolated static func canonicalImportSourceIdentity(for url: URL) -> String {
        AudioRepositoryFileIdentity.canonicalIdentity(for: url)
    }

    /// 解析单个拖放来源；无法解析出文件 URL 时返回 `nil`。
    nonisolated static func droppedFileURL(from provider: NSItemProvider) async throws -> URL? {
        try await AudioRepositoryDropResolver.droppedFileURL(from: provider)
    }

    /// 解析一批拖放来源，返回成功解析的 URL 与失败原因。
    nonisolated static func droppedFileURLs(from providers: [NSItemProvider]) async -> (urls: [URL], errors: [Error]) {
        await AudioRepositoryDropResolver.droppedFileURLs(from: providers)
    }

    /// 源文件是否可读（沙盒授权或本身可读）。
    nonisolated static func hasImportSourceAccess(_ source: URL, securityScopeGranted: Bool) -> Bool {
        AudioRepositoryImportService.hasImportSourceAccess(source, securityScopeGranted: securityScopeGranted)
    }

    // MARK: - 导入策略

    nonisolated static func shouldImportDroppedURLs(_ urls: [URL], after errors: [Error]) -> Bool {
        !urls.isEmpty
    }

    nonisolated static func shouldReportDroppedURLLoadFailure(_ urls: [URL], errors: [Error]) -> Bool {
        urls.isEmpty && !errors.isEmpty
    }

    nonisolated static func shouldReportPartialDroppedURLLoadFailure(_ urls: [URL], errors: [Error]) -> Bool {
        !urls.isEmpty && !errors.isEmpty
    }

    nonisolated static func shouldStartImport(isImporting: Bool) -> Bool {
        !isImporting
    }
}

// MARK: - Event Handler

extension AudioDBView {
    /// 处理用户将音频文件拖入仓库视图。
    ///
    /// 实际导入流程在 `AudioRepositoryImporter`（与文件选择器共用），这里只保留
    /// 一层转发，方便视图侧调用点保持直观。
    nonisolated func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        MainActor.assumeIsolated {
            importer.handleDrop(providers)
        }
    }
}
