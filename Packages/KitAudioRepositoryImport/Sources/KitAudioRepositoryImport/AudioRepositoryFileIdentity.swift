import Foundation
import MagicKit

/// 仓库文件身份：同一份文件的「同一性」判定。
///
/// 导入去重与列表去重必须用同一套判定，否则会出现「列表里认为是两份，
/// 导入时只导一份」这类不一致。放在 Kit 里供所有插件共用。
public enum AudioRepositoryFileIdentity {
    /// 文件的规范身份：解析符号链接后的标准化路径。
    ///
    /// 悬空符号链接（指向已删除目标）保留原路径，因为它无法被解析。
    public static func canonicalIdentity(for url: URL) -> String {
        guard url.isFileURL else {
            return url.standardized.absoluteString
        }

        if isDanglingSymlink(url) {
            return url.standardizedFileURL.path
        }

        return url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    /// 两个 URL 是否指向同一份文件。
    public static func representsSameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        canonicalIdentity(for: lhs) == canonicalIdentity(for: rhs)
    }

    private static func isDanglingSymlink(_ url: URL) -> Bool {
        guard (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true else {
            return false
        }

        return !FileManager.default.fileExists(atPath: url.path)
    }
}
