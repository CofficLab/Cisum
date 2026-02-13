import Foundation
import MagicKit
import OSLog
import SwiftUI

/// UI 数据仓库，负责处理 UI 相关的数据存取操作
@MainActor
class UIRepo: SuperLog, SuperThread {
    nonisolated static let emoji = "🎨"
    static let keyOfShowDB = "UI.ShowDB"

    /// 获取是否显示数据库视图的状态
    /// - Returns: 是否显示数据库视图
    func getShowDB() -> Bool {
        // 从 UserDefaults 获取值
        return UserDefaults.standard.bool(forKey: Self.keyOfShowDB)
    }

    /// 存储是否显示数据库视图的状态
    /// - Parameter value: 是否显示数据库视图
    func setShowDB(_ value: Bool) {
        // 存储到 UserDefaults
        UserDefaults.standard.set(value, forKey: Self.keyOfShowDB)
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

#Preview("UserDefaults 调试") {
    UserDefaultsDebugView(defaultSearchText: "UI.")
        .frame(width: 600)
        .frame(height: 800)
}
