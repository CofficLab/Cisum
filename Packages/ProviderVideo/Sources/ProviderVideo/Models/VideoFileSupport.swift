import Foundation
import UniformTypeIdentifiers

/// 视频文件支持的扩展名与导入类型。
public enum VideoFileSupport {
    /// 仓库扫描时视为视频的扩展名。
    public static let supportedExtensions: [String] = [
        "3gp", "avi", "m4v", "mkv", "mov", "mp4", "mpeg", "mpg", "webm",
    ]

    /// 判断某个文件扩展名是否受支持。
    public static func isSupported(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return supportedExtensions.contains(ext)
    }

    /// 导入面板使用的 UTType 集合。
    public static var importContentTypes: [UTType] {
        var types: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        for ext in supportedExtensions {
            if let type = UTType(filenameExtension: ext) {
                types.append(type)
            }
        }
        return types
    }
}

/// 标签文本的规范化。
///
/// 标签是纯字符串，没有独立的标签表：每个视频自带一组标签字符串。
public enum VideoTagSupport {
    /// 把用户输入的标签文本拆分成去重后的标签数组。
    ///
    /// 分隔符包含逗号（中英文）、分号（中英文）与换行。
    public static func normalizedTags(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",，;；\n")
        return text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { tags, tag in
                guard !tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) else {
                    return
                }
                tags.append(tag)
            }
    }

    /// 把标签数组拼回可编辑的文本。
    public static func editableText(from tags: [String]) -> String {
        tags.joined(separator: ", ")
    }
}
