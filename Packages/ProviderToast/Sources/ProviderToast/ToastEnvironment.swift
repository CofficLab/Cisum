import SwiftUI

private struct ToastProviderEnvironmentKey: EnvironmentKey {
    static let defaultValue: (any ToastProviding)? = nil
}

public extension EnvironmentValues {
    var toastProviding: (any ToastProviding)? {
        get { self[ToastProviderEnvironmentKey.self] }
        set { self[ToastProviderEnvironmentKey.self] = newValue }
    }
}
