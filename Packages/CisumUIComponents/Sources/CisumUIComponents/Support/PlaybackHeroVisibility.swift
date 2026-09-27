import SwiftUI

/// Shared layout signal published by the playback hero and consumed by the
/// player controls and root layout.
private struct PlaybackHeroVisibilityKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(true)
}

public extension EnvironmentValues {
    var playbackHeroVisibility: Binding<Bool> {
        get { self[PlaybackHeroVisibilityKey.self] }
        set { self[PlaybackHeroVisibilityKey.self] = newValue }
    }
}
