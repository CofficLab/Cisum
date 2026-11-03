import Foundation

/// 数据根目录的命名规则。
///
/// 插件数据目录的结构是：
///
/// ```text
/// <appSpecificSupport>/
/// └── db_debug_v<N>  |  db_production_v<N>   ← 数据根目录（databaseRoot）
///     ├── <pluginID>/                        ← 插件专属数据目录
///     └── Core/                              ← 共享 Core 目录
/// ```
///
/// ## 为什么放在 ProviderStorage
///
/// 「数据根目录叫什么」是**存储层知识**：它是所有插件数据目录的父目录，
/// 插件目录、历史目录迁移、调试入口都依赖它。若各插件各抄一份
/// `db_debug_v<N>`，改版本号策略时必然漏改一处——而漏改的后果是
/// 插件把数据写进另一个目录，用户看到「数据凭空消失」。
///
/// 因此这里是唯一一份定义，其它地方一律复用。
public enum DataRootDirectoryNaming {
    /// 数据根目录名：`db_<debug|production>_v<majorVersion>`。
    ///
    /// - Parameters:
    ///   - isDebug: 是否为 Debug 构建。
    ///   - majorVersion: App 主版本号（`"5.3.1" -> 5`）。
    /// - Returns: 目录名，如 `db_debug_v5`。
    public static func directoryName(isDebug: Bool, majorVersion: Int) -> String {
        let environment = isDebug ? "debug" : "production"
        return "db_\(environment)_v\(majorVersion)"
    }

    /// 数据根目录名：`db_<debug|production>_v<majorVersion>`。
    ///
    /// Debug / Release 与主版本号都取自当前进程，因此调用方无需关心
    /// 这两个维度。
    public static func directoryName() -> String {
        directoryName(isDebug: isDebugBuild, majorVersion: currentMajorVersion)
    }

    /// 数据根目录名：`db_<debug|production>_v<majorVersion>`。
    ///
    /// - Parameters:
    ///   - isDebug: 是否为 Debug 构建。
    ///   - versionString: App 版本号（`"5.3.1"`）；无法解析时回退 1。
    /// - Returns: 目录名，如 `db_debug_v5`。
    public static func directoryName(isDebug: Bool, versionString: String) -> String {
        directoryName(isDebug: isDebug, majorVersion: majorVersion(from: versionString))
    }

    /// 解析主版本号：`"5.3.1" -> 5`；无法解析时回退 1。
    public static func majorVersion(from versionString: String) -> Int {
        versionString.split(separator: ".").first.flatMap { Int($0) } ?? 1
    }

    /// 当前构建是否为 Debug。
    public static var isDebugBuild: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }

    /// 当前 App 的主版本号。
    public static var currentMajorVersion: Int {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1"
        return majorVersion(from: version)
    }
}
