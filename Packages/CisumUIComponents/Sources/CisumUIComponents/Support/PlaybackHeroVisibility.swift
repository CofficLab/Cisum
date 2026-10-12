import SwiftUI

/// Shared layout signal published by the playback hero and consumed by the
/// player controls and root layout.
///
/// The hero view publishes its visibility bottom-up with a `PreferenceKey`
/// instead of injecting a SwiftUI environment value, so business packages
/// keep their dependencies explicit (see `Scripts/check-plugin-boundaries.sh`).
public struct PlaybackHeroVisibilityKey: PreferenceKey {
    public static var defaultValue: Bool { true }

    public static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}
