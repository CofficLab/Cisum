import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// 宿主 app 的图标。
///
/// 引导面板要「像真的播放器」，封面位得放 app 自己的图标，而不是随手画一个
/// SF Symbol 占位。插件包拿不到宿主 target 的资源，只能在运行时向系统要：
/// macOS 直接用 `NSApplication.applicationIconImage`；iOS 需要从 Info.plist
/// 解析图标文件名。取不到时返回 `nil`，调用方回退到 SF Symbol。
@MainActor
enum HostAppIcon {
    /// 当前 app 的图标；取不到时返回 `nil`。
    static func image() -> Image? {
        #if os(macOS)
        // 只有跑在真正的 .app 里才有「宿主图标」可言；测试进程（xctest）
        // 的主 bundle 不是 .app，直接放弃，避免把测试宿主自己的图标画出来。
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return nil }
        return Image(nsImage: NSApplication.shared.applicationIconImage)
        #elseif os(iOS)
        return iOSImage()
        #endif
    }

    #if os(iOS)
    /// iOS 没有公开的「取 app 图标」接口，只能从 Info.plist 解析图标文件名，
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
