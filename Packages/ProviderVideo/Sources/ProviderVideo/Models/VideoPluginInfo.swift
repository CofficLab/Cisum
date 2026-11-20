import Foundation

/// 视频插件的固定信息。
///
/// 仓库子目录名与音乐（`audios`）、有声书（`audios_book`）平级：
/// 三者都在同一个存储根目录下各建各的子仓库，由 `StorageProviding` 决定
/// 根目录是 iCloud 容器还是本地目录。
public enum VideoPluginInfo {
    /// Release 构建下的仓库子目录名。
    public static let repositoryDirName = "videos"

    /// Debug 构建下的仓库子目录名（与音乐的 `audios_debug` 同策略）。
    public static let debugRepositoryDirName = "videos_debug"

    /// 当前构建生效的仓库子目录名。
    public static var effectiveRepositoryDirName: String {
        #if DEBUG
            debugRepositoryDirName
        #else
            repositoryDirName
        #endif
    }
}
