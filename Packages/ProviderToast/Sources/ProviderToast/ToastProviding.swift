import Foundation

@MainActor
public protocol ToastProviding: AnyObject {
    func show(_ toast: CisumToast)
    func presentError(title: String, message: String)
    func dismissError()
    func showLoading(title: String, detail: String?)
    func dismissLoading()
    func dismissAll()
}

public extension ToastProviding {
    func show(
        _ title: String,
        detail: String? = nil,
        style: CisumToastStyle = .info,
        duration: TimeInterval? = nil
    ) {
        show(CisumToast(title: title, detail: detail, style: style, duration: duration))
    }

    func info(_ title: String, detail: String? = nil, duration: TimeInterval = 3) {
        show(title, detail: detail, style: .info, duration: duration)
    }

    func success(_ title: String, detail: String? = nil, duration: TimeInterval = 3) {
        show(title, detail: detail, style: .success, duration: duration)
    }

    func warning(_ title: String, detail: String? = nil, duration: TimeInterval = 4) {
        show(title, detail: detail, style: .warning, duration: duration)
    }

    func error(_ title: String, detail: String? = nil, duration: TimeInterval? = nil) {
        if let duration {
            show(title, detail: detail, style: .error, duration: duration)
        } else {
            presentError(title: title, message: detail ?? title)
        }
    }

    func error(_ error: Error, title: String = "Error", duration: TimeInterval? = nil) {
        self.error(title, detail: error.localizedDescription, duration: duration)
    }
}
