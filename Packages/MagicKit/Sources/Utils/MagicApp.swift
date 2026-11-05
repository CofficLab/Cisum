import Foundation
import SwiftUI

#if os(macOS)
    import AppKit
#elseif os(iOS) || os(visionOS)
    import UIKit
#endif

/// 最小化 MagicApp 工具类
/// 提供 bundle identifier 和 iCloud 可用性检查
public enum MagicApp {
    /// Whether the current platform is a desktop platform.
    public static var isDesktop: Bool {
        #if os(macOS)
            return true
        #else
            return false
        #endif
    }

    /// Whether the current platform is iOS.
    public static var isiOS: Bool {
        #if os(iOS)
            return true
        #else
            return false
        #endif
    }

    /// Whether the current platform is not a desktop platform.
    public static var isNotDesktop: Bool {
        !isDesktop
    }

    /// 当前平台名称。
    public static var currentPlatform: String {
        #if os(macOS)
            return "macOS"
        #elseif os(iOS)
            return "iOS"
        #elseif os(visionOS)
            return "visionOS"
        #else
            return "unknown"
        #endif
    }

    /// 获取当前应用的 Bundle Identifier
    public static func getBundleIdentifier() -> String {
        Bundle.main.bundleIdentifier ?? "com.unknown.app"
    }

    /// 获取当前应用版本。
    public static func getVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    /// 获取当前应用名称。
    public static func getAppName() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
    }

    /// 获取当前应用构建号。
    public static func getBuildNumber() -> String {
        Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "Unknown"
    }

    /// 检查 iCloud 是否可用
    public static func isICloudAvailable() -> Bool {
        #if os(watchOS)
        return false
        #else
        return FileManager.default.ubiquityIdentityToken != nil
        #endif
    }

    /// 获取当前设备名称。
    public static func getDeviceName() -> String {
        #if os(macOS)
            return Host.current().localizedName ?? "Unknown"
        #elseif os(iOS) || os(visionOS)
            return UIDevice.current.name
        #else
            return "Unknown"
        #endif
    }

    /// 获取当前设备型号标识。
    public static func getDeviceModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)

        guard size > 0 else {
            return "Unknown"
        }

        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    /// 获取系统名称。
    public static func getSystemName() -> String {
        currentPlatform
    }

    /// 获取系统版本。
    public static func getSystemVersion() -> String {
        if let version = ProcessInfo.processInfo.operatingSystemVersionString.split(separator: " ").last {
            return String(version)
        }
        return "Unknown"
    }

    /// 获取 Application Support 目录。
    public static func getAppSupportDirectory() -> URL {
        (try? URL.applicationSupport) ?? FileManager.default.temporaryDirectory
    }

    /// 获取应用专属 Application Support 目录。
    public static func getAppSpecificSupportDirectory() -> URL {
        if let isolated = isolatedUITestRoot() {
            return isolated.appendingPathComponent("ApplicationSupport", isDirectory: true)
        }
        return (try? URL.appSpecificSupport) ?? FileManager.default.temporaryDirectory
    }

    /// 获取 Documents 目录。
    public static func getDocumentsDirectory() -> URL {
        if let isolated = isolatedUITestRoot() {
            return isolated.appendingPathComponent("Documents", isDirectory: true)
        }
        return (try? URL.documents) ?? FileManager.default.temporaryDirectory
    }

    /// UI 测试专用：隔离的数据根目录。
    ///
    /// 启动参数 `--cisum-ui-testing-isolated-storage=<目录名>` 让本次启动
    /// 的数据根落到临时目录下的独立子目录里，与真实沙盒完全隔离。
    ///
    /// 用途：需要「仓库确实是空的」这一前提的用例。上一次运行留下的
    /// 音频文件与数据库行会让仓库非空，单靠清理磁盘目录不够——数据库
    /// 里的行还在，列表照样有内容。
    ///
    /// 解析逻辑集中在 ``UITestIsolation``，本方法只做转发，
    /// 保证「路径怎么算」只有一处定义。
    private static func isolatedUITestRoot() -> URL? {
        #if DEBUG
            guard let root = UITestIsolation.isolatedRoot() else { return nil }
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            return root
        #else
            return nil
        #endif
    }

    /// 获取应用容器目录。
    public static func getContainerDirectory() -> URL {
        (try? URL.container) ?? FileManager.default.temporaryDirectory
    }

    /// 获取 iCloud 容器目录。
    public static func getCloudContainerDirectory() -> URL? {
        URL.cloudContainer
    }

    /// 获取 iCloud Documents 目录。
    ///
    /// ## UI 测试下的隔离
    ///
    /// UI 测试启用 iCloud 存储时，仓库落在**真实 iCloud 容器的隔离子目录**下，
    /// 而不是容器根部的 `Documents`：
    ///
    /// - **保留真实系统行为**：路径仍在 iCloud 容器内，因此
    ///   `NSMetadataQuery` 那条监控实现（与本地的 `DispatchSource` 是两套
    ///   完全不同的代码）仍会被走到——这正是 iCloud 专项用例要覆盖的东西；
    /// - **消除状态残留**：子目录由测试独占并被幂等清空，容器里开发者
    ///   自己同步的文件不会混进测试的仓库。
    ///
    /// 换句话说：**隔离的是「状态残留」，不是「系统行为」**。
    /// 这两件事可以正交，不必二选一。
    ///
    /// 前提是设备确实登录了 iCloud——没有账号时容器不存在，任何路径都
    /// 无法构造。这是真实的系统约束，UI 测试对此**显式 skip** 而不是
    /// 悄悄通过（见 `CisumUITestCase`）。
    public static func getCloudDocumentsDirectory() -> URL? {
        if let isolated = isolatedUITestCloudSubdirectory() {
            return isolated
        }
        return URL.cloudDocuments
    }

    /// UI 测试专用的 iCloud 隔离子目录。
    ///
    /// 位于真实 iCloud 容器的 `Documents/CisumUITest/<名称>` 下。
    private static func isolatedUITestCloudSubdirectory() -> URL? {
        #if DEBUG
            guard UITestIsolation.isUITesting(),
                  let container = URL.cloudContainer else { return nil }
            guard let name = UITestIsolation.isolatedStorageName(), !name.isEmpty else {
                return nil
            }
            let root = container
                .appendingPathComponent("Documents", isDirectory: true)
                .appendingPathComponent("CisumUITest", isDirectory: true)
                .appendingPathComponent(name, isDirectory: true)
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            return root
        #else
            return nil
        #endif
    }

    /// 获取缓存目录。
    public static func getCacheDirectory() -> URL {
        (try? URL.caches) ?? FileManager.default.temporaryDirectory
    }

    /// 获取数据库目录。
    public static func getDatabaseDirectory() -> URL {
        (try? URL.database) ?? FileManager.default.temporaryDirectory
    }

    /// 返回调试命令菜单。
    @available(iOS 14.0, macOS 11.0, *)
    public static func debugCommand() -> CommandMenu<some View> {
        CommandMenu("Debug") {
            Group {
                Button("Open App Support Directory") {
                    getAppSpecificSupportDirectory().open()
                }

                Button("Open Container Directory") {
                    getContainerDirectory().open()
                }

                Button("Open Documents Directory") {
                    getDocumentsDirectory().open()
                }

                Button("Open iCloud Documents") {
                    getCloudDocumentsDirectory()?.open()
                }

                Button("Open Cache Directory") {
                    getCacheDirectory().open()
                }

                Button("Open Downloads Directory") {
                    try? URL.downloads.open()
                }

                Button("Open Temporary Directory") {
                    URL.temp.open()
                }

                Button("Open iCloud Container") {
                    getCloudContainerDirectory()?.open()
                }

                Button("Open System App Support") {
                    try? URL.applicationSupport.open()
                }
            }
        }
    }
}
