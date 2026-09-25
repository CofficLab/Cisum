import CisumKernel
import CloudKit
import Foundation
import MagicKit
import ProviderCloud

/// `CloudProviding` 的具体实现。
///
/// 包装 `MagicApp.isICloudAvailable()` 并监听系统 `CKAccountChanged` 通知，
/// 对应旧版 `CloudVM` 暴露的面。
@MainActor
public final class CloudService: ObservableObject, CloudProviding {
    @Published public private(set) var isICloudAvailable: Bool = MagicApp.isICloudAvailable()
    @Published public private(set) var isSignedIn: Bool?

    public var accountStatusDescription: String {
        guard let isSignedIn else { return "Unknown" }
        return isSignedIn ? "Signed In" : "Not Signed In"
    }

    private var observer: NSObjectProtocol?
    private let eventObservers = KernelEventObserverStore<CloudProvidingEvent>()

    public init() {
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    private func refresh() {
        let available = MagicApp.isICloudAvailable()
        isICloudAvailable = available
        isSignedIn = available
        eventObservers.send(.availabilityChanged(isICloudAvailable: available, isSignedIn: isSignedIn))
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (CloudProvidingEvent) -> Void
    ) -> any CloudProvidingObserverHandle {
        eventObservers.add(callback)
    }
}
