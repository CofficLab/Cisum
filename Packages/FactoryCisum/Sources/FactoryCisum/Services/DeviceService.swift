import ProviderDevice
import Foundation
import MagicKit
#if canImport(AppKit)
    import AppKit
#endif
#if canImport(UIKit)
    import UIKit
#endif

/// `DeviceProviding` 的具体实现。
///
/// 包装 `MagicApp` 的设备/平台信息，并提供屏幕尺寸（macOS 取主屏幕，iOS 取主 UIScreen）。
@MainActor
public final class DeviceService: ObservableObject, DeviceProviding {
    public var isMac: Bool { MagicApp.isDesktop }
    public var isIOS: Bool { MagicApp.isiOS }

    public var isPad: Bool {
        #if os(iOS)
            return UIDevice.current.userInterfaceIdiom == .pad
        #else
            // visionOS 没有 iPad 这一形态：空间计算的设备既不是 iPhone 也不是 iPad，
            // 「是否 iPad」在 visionOS 上恒为 false。
            return false
        #endif
    }

    public var deviceModel: String { MagicApp.getDeviceModel() }
    public var systemVersion: String { MagicApp.getSystemVersion() }

    public var screenWidth: CGFloat { primaryScreenSize.width }
    public var screenHeight: CGFloat { primaryScreenSize.height }

    public init() {}

    private var primaryScreenSize: CGSize {
        #if os(macOS)
            return NSScreen.main?.frame.size ?? .zero
        #elseif os(iOS)
            return UIScreen.main.bounds.size ?? .zero
        #else
            // visionOS 没有 `UIScreen`（空间计算的显示尺寸由窗口/沉浸空间决定，
            // 不存在「主屏幕」这一概念）。这里返回零值：visionOS 上的布局
            // 不依赖主屏幕尺寸，而依赖窗口尺寸。
            return .zero
        #endif
    }
}
