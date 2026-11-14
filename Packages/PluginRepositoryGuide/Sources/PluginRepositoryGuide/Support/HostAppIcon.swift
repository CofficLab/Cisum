import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

/// 宿主 app 的图标。
///
/// 引导面板要「像真的播放器」，封面位得放 app 自己的图标，而不是随手画一个
/// SF Symbol 占位。插件包拿不到宿主 target 的资源，只能在运行时向系统要：
/// macOS 用 `NSWorkspace.icon(forFile:)` 读取 app 包路径获取原始高清图标；
/// iOS 需要从 Info.plist 解析图标文件名。取不到时返回 `nil`，调用方回退到
/// SF Symbol。
///
/// ### 为什么不用 `NSApplication.shared.applicationIconImage`？
///
/// 该属性返回系统缓存的显示尺寸图标，分辨率通常只有 128×128 或 512×512。
/// 引导面板封面区域会将图标拉伸到 200+pt（Retina 下需要 400+px），小图标
/// 放大后会明显模糊。改用 `NSWorkspace.icon(forFile:)` 直接读取 app 包路径，
/// 系统会从 .iconset 中挑选匹配尺寸的最佳分辨率表示。
@MainActor
enum HostAppIcon {
    /// 当前 app 的图标；取不到时返回 `nil`。
    static func image() -> Image? {
        #if os(macOS)
        // 只有跑在真正的 .app 里才有「宿主图标」可言；测试进程（xctest）
        // 的主 bundle 不是 .app，直接放弃，避免把测试宿主自己的图标画出来。
        let appPath = Bundle.main.bundlePath
        guard appPath.hasSuffix(".app") else { return nil }
        let nsImage = NSWorkspace.shared.icon(forFile: appPath)
        // 显式设为大尺寸，让 NSImage 从 .iconset 中加载最佳分辨率表示，
        // 避免系统返回缓存的小尺寸图标导致放大模糊。
        nsImage.size = NSSize(width: 1024, height: 1024)
        return Image(nsImage: nsImage)
        #elseif os(iOS) || os(visionOS)
        return iOSImage()
        #endif
    }

    #if os(iOS) || os(visionOS)
    /// iOS / visionOS 没有公开的「取 app 图标」接口，只能从 Info.plist 解析图标文件名，
    /// 再退回扫描 bundle 根目录里以 AppIcon 开头的 png。
    private static func iOSImage() -> Image? {
        var candidates: [String] = []

        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any] {
            for value in icons.values {
                guard let primary = value as? [String: Any] else { continue }
                if let files = primary["CFBundleIconFiles"] as? [String] {
                    candidates += files
                }
                if let name = primary["CFBundleIconName"] as? String {
                    candidates.append(name)
                }
            }
        }
        if let files = Bundle.main.infoDictionary?["CFBundleIconFiles"] as? [String] {
            candidates += files
        }

        for name in candidates {
            if let path = Bundle.main.path(forResource: name, ofType: "png"),
               let image = UIImage(contentsOfFile: path) {
                return Image(uiImage: image)
            }
        }

        let bundled = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? []
        guard let url = bundled.first(where: { $0.lastPathComponent.hasPrefix("AppIcon") }),
              let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        return Image(uiImage: image)
    }
    #endif
}
