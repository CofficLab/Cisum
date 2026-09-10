import Foundation
import ProviderToast
import Combine

public final class ToastProvider: ObservableObject, ToastProviding {
    @Published public private(set) var currentToast: CisumToast?
    @Published public private(set) var currentError: CisumErrorNotice?
    @Published public private(set) var currentLoading: CisumLoadingNotice?

    private var dismissTask: Task<Void, Never>?
    private static let defaultDuration: TimeInterval = 3

    nonisolated public init() {}

    @MainActor
    public func show(_ toast: CisumToast) {
        currentLoading = nil
        currentToast = toast
        dismissTask?.cancel()

        let duration = toast.duration ?? Self.defaultDuration
        guard duration > 0 else { return }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.currentToast = nil
        }
    }

    @MainActor
    public func presentError(title: String, message: String) {
        currentError = CisumErrorNotice(title: title, message: message)
    }

    @MainActor
    public func dismissError() {
        currentError = nil
    }

    @MainActor
    public func showLoading(title: String, detail: String?) {
        dismissTask?.cancel()
        currentToast = nil
        currentLoading = CisumLoadingNotice(title: title, detail: detail)
    }

    @MainActor
    public func dismissLoading() {
        currentLoading = nil
    }

    @MainActor
    public func dismissAll() {
        dismissTask?.cancel()
        currentToast = nil
        currentError = nil
        currentLoading = nil
    }
}
