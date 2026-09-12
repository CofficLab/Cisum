import Foundation
import ProviderScene

/// PluginPlayBack 的播放状态存储服务（Services 层）。
///
/// 专门负责把当前播放文件按「场景 + 文件」持久化到插件专属磁盘目录，
/// 下次启动或切换场景时恢复。仅有此插件维护该状态，不依赖 `UserDefaults`。
///
/// ## 文件
/// - 路径：`<rootDirectory>/PluginPlayBack/current-playback.plist`
/// - 格式：binary plist，`[String: String]`，键为场景名（`AppScene.rawValue`），
///   值为 URL 的 absoluteString；`url` 键保留给旧版全局记录做一次性迁移。
@MainActor
public final class PlaybackStateStore {
    private static let subdirectory = "PluginPlayBack"
    private static let filename = "current-playback.plist"
    /// 旧版单一全局记录的键（场景化前的 `["url": String]` 格式），用于升级迁移。
    private static let legacyURLKey = "url"

    private let fileURL: URL

    /// - Parameter rootDirectory: 数据库根目录（`kernel.storage?.databaseRoot`）。
    public init(rootDirectory: URL) {
        self.fileURL = rootDirectory
            .appendingPathComponent(Self.subdirectory, isDirectory: true)
            .appendingPathComponent(Self.filename, isDirectory: false)
    }

    /// 保存指定场景的当前播放文件；传 `nil` 表示清除该场景的记录。
    public func saveCurrentFile(_ url: URL?, for scene: AppScene) {
        var dict = loadDictionary() ?? [:]
        // Once a scene-specific write occurs, the legacy global value must not
        // be inherited by another scene on its first read.
        dict.removeValue(forKey: Self.legacyURLKey)
        if let url {
            dict[scene.rawValue] = url.absoluteString
        } else {
            dict.removeValue(forKey: scene.rawValue)
        }

        if dict.isEmpty {
            try? FileManager.default.removeItem(at: fileURL)
        } else {
            write(dict)
        }
    }

    /// 读取指定场景上次播放的文件；无记录时返回 `nil`。
    ///
    /// 首次读取到旧版全局 `url` 记录时，会把它迁移到当前场景的槽位并移除旧键，
    /// 避免旧记录被后续场景重复继承。
    public func loadCurrentFile(for scene: AppScene) -> URL? {
        guard var dict = loadDictionary() else { return nil }

        if let urlString = dict[scene.rawValue] {
            let url = URL(string: urlString)
            if dict.removeValue(forKey: Self.legacyURLKey) != nil {
                write(dict)
            }
            return url
        }

        if let legacy = dict[Self.legacyURLKey], let url = URL(string: legacy) {
            dict.removeValue(forKey: Self.legacyURLKey)
            dict[scene.rawValue] = legacy
            write(dict)
            return url
        }

        return nil
    }

    // MARK: - Private

    private func loadDictionary() -> [String: String]? {
        guard let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: String] else {
            return nil
        }
        return dict
    }

    private func write(_ dict: [String: String]) {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(
                fromPropertyList: dict,
                format: .binary,
                options: 0
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // 写入失败不影响播放。
        }
    }
}
