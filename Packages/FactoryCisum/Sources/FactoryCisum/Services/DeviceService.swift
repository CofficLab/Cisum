import CisumKernel
import Foundation
import MagicKit
import ProviderDevice
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
            return .zero
        #endif
    }
}
