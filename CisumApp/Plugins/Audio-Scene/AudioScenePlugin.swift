import Foundation
import MagicKit
import OSLog
import SwiftData
import SwiftUI

actor AudioScenePlugin: SuperPlugin {
    static var shouldRegister: Bool { true }
    static var order: Int { 0 }
    let title = "Music Scene"
    let description = "Provides music library scene"
    let iconName = "music.note.list"
    static let sceneName = "Music Library"

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
