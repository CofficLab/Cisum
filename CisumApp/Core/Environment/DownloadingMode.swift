import SwiftUI

// MARK: - Environment Key for Downloading Mode

struct DownloadingModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// 是否是下载中场景
    var downloadingMode: Bool {
        get { self[DownloadingModeKey.self] }
        set { self[DownloadingModeKey.self] = newValue }
    }
}

// MARK: - View Extension for Downloading Mode

extension View {
    /// 设置为下载中场景
    func inDownloadingMode() -> some View {
        self.environment(\.downloadingMode, true)
    }
}

// MARK: Preview

#Preview("Downloading Mode") {
    Text("Downloading Mode Example", tableName: "Core")
        .inDownloadingMode()
}
