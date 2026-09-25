import Foundation
import SwiftUI

@MainActor
public enum DeviceProvidingEvent {
    case deviceChanged
}

@MainActor
public protocol DeviceProvidingObserverHandle: AnyObject {
    func cancel()
}

/// 设备数据服务能力协议。
///
/// 提供当前设备信息和平台适配数据。
///
/// ## 使用示例
///
/// ```swift
/// let isMac = kernel.resolveProvider((any DeviceProviding).self)?.isMac ?? false
/// let isPad = kernel.resolveProvider((any DeviceProviding).self)?.isPad ?? false
/// ```
@MainActor
public protocol DeviceProviding: AnyObject, ObservableObject {
    /// 当前是否为 macOS。
    var isMac: Bool { get }

    /// 当前是否为 iOS。
    var isIOS: Bool { get }

    /// 当前是否为 iPad。
    var isPad: Bool { get }

    /// 当前设备型号标识。
    var deviceModel: String { get }

    /// 系统版本字符串。
    var systemVersion: String { get }

    /// 可用屏幕宽度。
    var screenWidth: CGFloat { get }

    /// 可用屏幕高度。
    var screenHeight: CGFloat { get }

    @discardableResult
    func addObserver(_ callback: @escaping (DeviceProvidingEvent) -> Void) -> any DeviceProvidingObserverHandle
}

public extension DeviceProviding {
    @discardableResult
    func addObserver(_ callback: @escaping (DeviceProvidingEvent) -> Void) -> any DeviceProvidingObserverHandle {
        NoopDeviceProvidingObserverHandle()
    }
}

@MainActor
public final class NoopDeviceProvidingObserverHandle: DeviceProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}
