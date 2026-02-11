import Foundation
import MagicKit
import OSLog
import SwiftData
import SwiftUI

actor BookScenePlugin: SuperPlugin {
    static var shouldRegister: Bool { false }
    static var order: Int { 0 }
    let title = "Audiobook Scene"
    let description = "Provides audiobook scene"
    let iconName = "book.closed"
    static let sceneName = "Audiobooks"

    /// Provides "Audiobooks" scene
    @MainActor func addSceneItem() -> String? {
        return Self.sceneName
    }

    /// 提供有声书封面视图
    @MainActor
    func addPosterView() -> AnyView? {
        AnyView(BookPoster())
    }
}

// MARK: - Preview

#if os(macOS)
#Preview("App - Large") {
    ContentView()
    .inRootView()
        .frame(width: 600, height: 1000)
}

#Preview("App - Small") {
    ContentView()
    .inRootView()
        .frame(width: 600, height: 600)
}
#endif

#if os(iOS)
#Preview("iPhone") {
    ContentView()
    .inRootView()
}
#endif
