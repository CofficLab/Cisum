@MainActor
public final class DefaultToastProvider: ToastProviding {
    public init() {}

    public func show(_ toast: CisumToast) {}
    public func presentError(title: String, message: String) {}
    public func dismissError() {}
    public func showLoading(title: String, detail: String?) {}
    public func dismissLoading() {}
    public func dismissAll() {}
}
