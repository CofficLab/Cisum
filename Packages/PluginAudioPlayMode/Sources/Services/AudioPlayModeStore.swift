import Foundation
import CisumUIComponents
import MagicPlayMan
import OSLog

public actor AudioPlayModeStore: SuperLog {

    public static let emoji = "💾"
    public static let verbose = false

    public static let shared = AudioPlayModeStore()

    private static let playModeKey = "audioPlayMode"

    private init() {}

    public func getPlayMode() -> MagicPlayMode {
        Self.resolvedPlayMode(
            localRawValue: UserDefaults.standard.string(forKey: Self.playModeKey),
            cloudRawValue: NSUbiquitousKeyValueStore.default.string(forKey: Self.playModeKey)
        )
    }

    static func resolvedPlayMode(localRawValue: String?, cloudRawValue: String?) -> MagicPlayMode {
        if let localRawValue, let playMode = MagicPlayMode(rawValue: localRawValue) {
            return playMode
        }

        if let cloudRawValue, let playMode = MagicPlayMode(rawValue: cloudRawValue) {
            return playMode
        }

        return .sequence
    }

    public func storePlayMode(_ mode: MagicPlayMode) {
        storePlayModeRawValue(mode.rawValue, shortName: mode.shortName)
    }

    public func storePlayModeRawValue(_ modeString: String, shortName: String) {
        UserDefaults.standard.set(modeString, forKey: Self.playModeKey)

        NSUbiquitousKeyValueStore.default.set(modeString, forKey: Self.playModeKey)
        NSUbiquitousKeyValueStore.default.synchronize()

        if Self.verbose {
            os_log("\(self.t)💾 Saved play mode: \(shortName)")
        }
    }

    public func resetToDefault() {
        let defaultMode = MagicPlayMode.sequence
        storePlayMode(defaultMode)

        if Self.verbose {
            os_log("\(self.t)🔄 Reset play mode to default: \(defaultMode.shortName)")
        }
    }

    public func getAvailableModes() -> [MagicPlayMode] {
        [.sequence, .repeatAll, .loop, .shuffle]
    }

    public func isModeAvailable(_ mode: MagicPlayMode) -> Bool {
        getAvailableModes().contains(mode)
    }
}
