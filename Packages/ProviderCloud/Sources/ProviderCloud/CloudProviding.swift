import Foundation
import KitEventObservation

@MainActor
public enum CloudProvidingEvent {
    case availabilityChanged(isICloudAvailable: Bool, isSignedIn: Bool?)
}

@MainActor
public protocol CloudProvidingObserverHandle: AnyObject {
    func cancel()
}

/// 云同步服务能力协议。
///
/// 包装 `MagicApp.isICloudAvailable()` 与系统 `CKAccountChanged` 通知，
/// 对应旧版 `CloudVM` 暴露的面。iCloud 可用性是一个布尔判定
/// （`FileManager.ubiquityIdentityToken != nil`），账户变化通过系统通知感知。
@MainActor
public protocol CloudProviding: AnyObject, ObservableObject {
    /// iCloud 是否可用。
    var isICloudAvailable: Bool { get }

    /// 是否已登录 iCloud 账户；`nil` 表示尚未确定。
    var isSignedIn: Bool? { get }

    /// 账户状态的可读描述。
    var accountStatusDescription: String { get }

    @discardableResult
    func addObserver(_ callback: @escaping (CloudProvidingEvent) -> Void) -> any CloudProvidingObserverHandle
}

public extension CloudProviding {
    @discardableResult
    func addObserver(_ callback: @escaping (CloudProvidingEvent) -> Void) -> any CloudProvidingObserverHandle {
        NoopCloudProvidingObserverHandle()
    }
}

@MainActor
public final class NoopCloudProvidingObserverHandle: CloudProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}

extension EventObserverHandle: CloudProvidingObserverHandle {}
