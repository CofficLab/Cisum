import Foundation
import SwiftUI

// MARK: - Store Events

extension Notification.Name {
    /// 商店交易更新事件
    static let storeTransactionUpdated = Notification.Name("store.transaction.updated")

    /// 商店恢复购买完成事件
    static let Restored = Notification.Name("store.restored")
}

// MARK: - View Extensions

/// SwiftUI View 扩展，提供便捷的商店相关事件监听
extension View {
    /// 监听商店恢复完成事件
    /// - Parameter action: 商店恢复完成时执行的操作
    /// - Returns: 添加了监听器的视图
    func onRestored(perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .Restored), perform: action)
    }

    /// 监听商店交易更新事件
    /// - Parameter action: 商店交易更新时执行的操作，参数为 productID
    /// - Returns: 添加了监听器的视图
    func onStoreTransactionUpdated(perform action: @escaping (String?) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .storeTransactionUpdated)) { notification in
            let productID = notification.object as? String
            action(productID)
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
