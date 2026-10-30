#if os(macOS)
import Foundation
import MagicKit
import LumiUI
import ProviderAudioLibrary
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
    static var capacity: (any AudioCopyCapacityCapability)?
    static var purchase: (any AudioCopyPurchaseCapability)?
    static var copyViewModel: CopyViewModel?
    static var copyObserver: CopyTaskObserver?

    /// 由插件入口注入能力（能力协议为插件内部类型，故本方法不对外）。
    static func configure(
        library: any AudioCopyLibraryCapability,
        toast: (any AudioCopyToastCapability)?,
        capacity: any AudioCopyCapacityCapability,
        purchase: any AudioCopyPurchaseCapability
    ) {
        Self.library = library
        Self.toast = toast
        Self.capacity = capacity
        Self.purchase = purchase
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

    /// 仓库是否已被当前用户的容量上限挡住。
    ///
    /// 判定经**容量闸门**（`AudioCapacityProviding`）完成：额度规则只在
    /// 数据层存在一处，各写入入口不再各自重算——否则漏掉一个入口就成了
    /// 绕过路径。
    static func isOutOfLimit() async -> Bool {
        let admission = await admission(requestedCount: 1)
        return admission.didReject
    }

    /// 本次请求实际能放行几个文件。
    static func allowedTaskCount(requestedTaskCount: Int) async -> Int {
        let admission = await admission(requestedCount: requestedTaskCount)
        return admission.allowedCount(requestedCount: requestedTaskCount)
    }

    /// 向闸门请求准入判定。
    ///
    /// `reservedCount` 传入**进行中的复制任务数**：复制是异步的，未落盘的
    /// 任务已经占了位。不计入它们，连续两次拖放都会读到同一个仓库计数，
    /// 从而双双放行、最终超限。
    static func admission(requestedCount: Int) async -> AudioCapacityAdmission {
        guard let capacity else {
            return .admitted
        }
        let pendingCount = await pendingCopyTaskCount()
        return await capacity.admit(requestedCount: requestedCount, reservedCount: pendingCount)
    }

    /// 撞限后呈现购买面板（可点击的付费入口）。
    static func presentPurchase() {
        purchase?.presentPurchase()
    }

    /// 当前订阅档位的显示名（经容量能力读取，不直接依赖商店服务）。
    static var tierDisplayName: String {
        capacity?.tierDisplayName ?? String(localized: "Free version", bundle: .module)
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
