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
    static var audioDiskProvider: (() -> URL?)?
    static var audioCountProvider: (() async -> Int)?
    static var toastProvider: (any ToastProviding)?
    static var copyViewModel: CopyViewModel?
    static var copyObserver: CopyTaskObserver?

    public static func configure(
        audioDiskProvider: @escaping () -> URL?,
        audioCountProvider: @escaping () async -> Int,
        toastProvider: (any ToastProviding)?
    ) {
        Self.audioDiskProvider = audioDiskProvider
        Self.audioCountProvider = audioCountProvider
        Self.toastProvider = toastProvider
        installCopyState()
    }

    static func installCopyState() {
        guard copyViewModel == nil else { return }
        let viewModel = CopyViewModel(toastProvider: toastProvider)
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
        guard let audioCountProvider else {
            return false
        }
        let count = await audioCountProvider()
        let pendingCount = await pendingCopyTaskCount()
        return count + pendingCount >= AudioPluginInfo.maxAudioCount && StoreService.tierCached().isFreeVersion
    }

    static func allowedTaskCount(requestedTaskCount: Int) async -> Int {
        guard let audioCountProvider else {
            return requestedTaskCount
        }

        let count = await audioCountProvider()
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
        audioDiskProvider?()
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
