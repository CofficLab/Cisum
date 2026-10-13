#if os(macOS)
import Foundation
import CisumUIComponents
import MagicKit
import LumiUI
import ProviderAudioLibrary
import ProviderStore
import ProviderToast
import SwiftData
import SwiftUI

@MainActor
public enum AudioCopyService {
    static var worker: CopyWorker?
    static var db: CopyDB?
    static var container: ModelContainer?
    /// 能力由入口经 `configure` 注入并由静态属性长期持有（视同组装层所有权）；
    /// 能力内部对 Provider 为惰性解析或 `weak`，静态持有不会延长 Provider 生命周期。
    static var library: (any AudioCopyLibraryCapability)?
    static var toast: (any AudioCopyToastCapability)?
    static var copyViewModel: CopyViewModel?
    static var copyObserver: CopyTaskObserver?

    /// 由插件入口注入能力（能力协议为插件内部类型，故本方法不对外）。
    static func configure(
        library: any AudioCopyLibraryCapability,
        toast: (any AudioCopyToastCapability)?
    ) {
        Self.library = library
        Self.toast = toast
        installCopyState()
    }

    static func installCopyState() {
        guard copyViewModel == nil else { return }
        let viewModel = CopyViewModel(toast: toast)
        let observer = CopyTaskObserver(viewModel: viewModel)
        copyViewModel = viewModel
        copyObserver = observer
    }

    public static func getStateView() -> AnyView {
        installCopyState()
        guard let viewModel = copyViewModel else {
            return AnyView(CopyStateView(viewModel: CopyViewModel()))
        }
        return AnyView(CopyStateView(viewModel: viewModel))
    }

    public static func getRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView where Content: View {
        AnyView(CopyRootView { content() })
    }

    static func getWorker() -> CopyWorker? {
        if let worker {
            return worker
        }

        if let db = getDB() {
            worker = CopyWorker(db: db, reason: "AudioCopyService")
        }

        return worker
    }

    static func getDB() -> CopyDB? {
        if let db {
            return db
        }

        if let container = try? getContainer() {
            let db = CopyDB(container, reason: "AudioCopyService", verbose: false)
            Self.db = db
            return db
        }

        return nil
    }

    static func getContainer() throws -> ModelContainer {
        if let container {
            return container
        }

        let url = try createDatabaseFile(name: "copy_db")
        let schema = Schema([
            CopyTask.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        Self.container = container
        return container
    }

    static func isOutOfLimit() async -> Bool {
        guard let library else {
            return false
        }
        let count = await library.totalCount()
        let pendingCount = await pendingCopyTaskCount()
        return count + pendingCount >= AudioPluginInfo.maxAudioCount && StoreService.tierCached().isFreeVersion
    }

    static func allowedTaskCount(requestedTaskCount: Int) async -> Int {
        guard let library else {
            return requestedTaskCount
        }

        let count = await library.totalCount()
        let pendingCount = await pendingCopyTaskCount()
        return AudioCopyLimitPolicy.allowedTaskCount(
            currentAudioCount: count,
            pendingCopyTaskCount: pendingCount,
            requestedTaskCount: requestedTaskCount,
            maxAudioCount: AudioPluginInfo.maxAudioCount,
            isFreeVersion: StoreService.tierCached().isFreeVersion
        )
    }

    static func getAudioDisk() -> URL? {
        library?.audioDisk
    }

    private static func pendingCopyTaskCount() async -> Int {
        guard let db = getDB() else {
            return 0
        }

        let tasks = await db.allCopyTaskDTOs()
        return tasks.filter(\.error.isEmpty).count
    }

    private static func createDatabaseFile(name: String) throws -> URL {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1"
        let majorVersion = version.split(separator: ".").first.flatMap { Int($0) } ?? 1
        let env = Self.dbDirName(majorVersion: majorVersion)
        let appSupport = MagicApp.getAppSpecificSupportDirectory()
        let url = appSupport
            .appendingPathComponent(env, isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
            .appendingPathComponent("\(name).db")

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        return url
    }

    private static func dbDirName(majorVersion: Int) -> String {
        #if DEBUG
            "db_debug_v\(majorVersion)"
        #else
            "db_production_v\(majorVersion)"
        #endif
    }
}
#endif
