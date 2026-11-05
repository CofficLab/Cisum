import Foundation

/// UI 测试的隔离数据根。
///
/// ## 为什么需要这一层
///
/// UI 测试的默认启动路径曾经**不是**从全新环境开始的：
///
/// - 基类只带 `--cisum-ui-testing --cisum-ui-testing-storage-local`，
///   仓库落在 App 的真实沙盒里，上一次运行留下的音频文件与数据库行
///   仍在，仓库「空」只是最终一致而非确定；
/// - `resetUITestAudioStateIfRequested` 只删磁盘目录，**不删数据库里的行**，
///   于是列表照样有内容；
/// - 开发者自己跑 Debug App 导入的真实音频会混进 UI 测试的仓库。
///
/// 引入本类型后，UI 测试的默认路径变成：
///
/// 1. 数据根落到临时目录下的独立子目录（与真实沙盒完全隔离）；
/// 2. 启动时**幂等清空**该目录（含数据库文件），再重新播种种子数据。
///
/// 于是「仓库为空」「仓库有一首种子音频」都成为**确定性前提**，
/// 不再依赖上一次运行的残留，也不受开发者本地环境影响。
///
/// ## 幂等重建而非随机重建
///
/// 刻意**不**用随机目录名：随机会让「上次失败的场景」这次不复现，
/// 只剩一句「它昨天挂过一次」。这里用**固定的结构 + 幂等的清理**：
///
/// - 目录名稳定（由用例名派生），失败现场可寻址、可复现；
/// - 每次启动先清空再重建，保证内容确定。
///
/// 两者不冲突：结构固定，内容可寻址。
public enum UITestIsolation {
    /// 启动参数前缀：`--cisum-ui-testing-isolated-storage=<目录名>`。
    public static let launchArgumentPrefix = "--cisum-ui-testing-isolated-storage="

    /// 隔离根目录的父目录。
    ///
    /// 位于系统临时目录下——UI 测试的产物本就不该持久化，
    /// 系统清理临时目录时自然回收。
    public static var containerRoot: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("cisum-ui-testing", isDirectory: true)
    }

    /// 解析本次启动的隔离根目录。
    ///
    /// - Parameter arguments: 启动参数。默认取 `ProcessInfo.processInfo.arguments`。
    /// - Returns: 隔离根目录；未启用隔离时返回 `nil`。
    public static func isolatedRoot(arguments: [String] = ProcessInfo.processInfo.arguments) -> URL? {
        #if DEBUG
            guard let argument = arguments.first(where: { $0.hasPrefix(launchArgumentPrefix) }) else {
                return nil
            }
            let name = String(argument.dropFirst(launchArgumentPrefix.count))
                .trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }
            return containerRoot.appendingPathComponent(name, isDirectory: true)
        #else
            return nil
        #endif
    }

    /// 解析本次启动使用的隔离目录名。
    ///
    /// - Parameter arguments: 启动参数。默认取 `ProcessInfo.processInfo.arguments`。
    /// - Returns: 目录名；未启用隔离时返回 `nil`。
    public static func isolatedStorageName(arguments: [String] = ProcessInfo.processInfo.arguments) -> String? {
        #if DEBUG
            guard let argument = arguments.first(where: { $0.hasPrefix(launchArgumentPrefix) }) else {
                return nil
            }
            let name = String(argument.dropFirst(launchArgumentPrefix.count))
                .trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : name
        #else
            return nil
        #endif
    }

    /// 是否处于 UI 测试模式。
    public static func isUITesting(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        #if DEBUG
            return arguments.contains("--cisum-ui-testing")
        #else
            return false
        #endif
    }

    /// **幂等重建**隔离根目录：清空内容并重新创建。
    ///
    /// 这一步是「仓库为空」成为确定性前提的关键——只清磁盘目录是不够的，
    /// 数据库里的行也必须一起清掉（数据库文件就落在该根目录下）。
    ///
    /// - Parameter arguments: 启动参数。
    /// - Returns: 被重建的隔离根目录；未启用隔离时返回 `nil`。
    @discardableResult
    public static func resetIsolatedRootIfNeeded(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> URL? {
        #if DEBUG
            guard isUITesting(arguments: arguments),
                  let root = isolatedRoot(arguments: arguments) else { return nil }

            let fileManager = FileManager.default
            // 整个根目录删掉重建：磁盘目录、SwiftData 数据库文件、
            // 插件数据目录全部一次性清空，不给残留留任何缝隙。
            if fileManager.fileExists(atPath: root.path) {
                try? fileManager.removeItem(at: root)
            }
            try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            return root
        #else
            return nil
        #endif
    }

    // MARK: - 偏好存储隔离

    /// UI 测试模式下的隔离偏好 suite 名。
    ///
    /// 与 ``isolatedStorageName`` 同源：**同一个用例类**的多次运行共享同一份
    /// 偏好，**不同用例类**之间互不影响。
    ///
    /// ## 为什么偏好也要隔离
    ///
    /// `UserDefaults.standard` 是**进程级全局状态**，跨用例共享。于是：
    ///
    /// - `CisumContentVisibilityUITests` 收起内容区 → 写真实偏好；
    /// - `CisumWelcomeUITests` 不带 `-UI.ContentViewVisible` 覆盖参数
    ///   （它需要走真实落盘路径），于是读到那个被写坏的偏好 → 内容区保持收起
    ///   → 断言「音乐库可见」失败。
    ///
    /// 这类污染让测试结论依赖**执行顺序**，违反「同一份测试在不同机器上
    /// 必须得到相同结论」的底线。偏好与数据根同源隔离后，用例之间不再互相
    /// 干扰，顺序也不再影响结论。
    ///
    /// ## 命名
    ///
    /// 用 suite 名而非文件路径，因为 `UserDefaults(suiteName:)` 本身就
    /// 提供独立命名空间，无需再手工建目录或清文件。
    public static func isolatedDefaultsSuiteName(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> String? {
        #if DEBUG
            guard isUITesting(arguments: arguments),
                  let name = isolatedStorageName(arguments: arguments) else { return nil }
            return "cisum.ui-testing.\(name)"
        #else
            return nil
        #endif
    }

    /// UI 测试模式下的隔离偏好存储。
    ///
    /// - Returns: 隔离的 `UserDefaults`；未启用隔离时返回 `nil`
    ///   （调用方应回落到 `UserDefaults.standard`）。
    public static func isolatedDefaults(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> UserDefaults? {
        #if DEBUG
            guard let suiteName = isolatedDefaultsSuiteName(arguments: arguments) else { return nil }
            // suite 独立于标准域：写入不会污染开发者真实偏好，
            // 也不会被参数域（`-UI.ContentViewVisible YES`）之外的持久化域影响。
            guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
            return defaults
        #else
            return nil
        #endif
    }
}
