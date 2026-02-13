import Foundation
import MagicKit
import OSLog
import SwiftData
import SwiftUI

actor AudioScenePlugin: SuperPlugin {
    static var shouldRegister: Bool { true }
    static var order: Int { 0 }

    nonisolated var title: String { String(localized: "Music Scene") }
    nonisolated var description: String { String(localized: "Provides music library scene") }
    let iconName = "music.note.list"
    static let sceneName = String(localized: "Music Library")

    /// Provides "Music Library" scene
    @MainActor func addSceneItem() -> String? {
        return Self.sceneName
    }

    /// 提供音频海报视图
    @MainActor
    func addPosterView() -> AnyView? {
        AnyView(AudioPoster())
    }
}

// MARK: - Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
