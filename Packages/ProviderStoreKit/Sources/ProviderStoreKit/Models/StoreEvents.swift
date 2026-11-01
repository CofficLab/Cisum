import Foundation
import SwiftUI

public extension Notification.Name {
    static let storeTransactionUpdated = Notification.Name("store.transaction.updated")
    static let Restored = Notification.Name("store.restored")
}

public extension View {
    func onRestored(perform action: @escaping (Notification) -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .Restored), perform: action)
    }

    func onStoreTransactionUpdated(perform action: @escaping (String?) -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .storeTransactionUpdated)) { notification in
            let productID = notification.object as? String
            action(productID)
        }
    }
}
