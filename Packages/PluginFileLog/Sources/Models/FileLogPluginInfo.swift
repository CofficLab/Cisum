import Foundation

public enum FileLogPluginInfo {
    public static let title = String(localized: "File Log", bundle: .module)
    public static let description = String(
        localized: "Collect OSLog entries to disk files with auto-rotation and cleanup",
        bundle: .module
    )
    public static let iconName = "doc.text.below.ecg"
}
