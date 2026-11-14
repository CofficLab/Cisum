import Foundation

/// 表示一次 Git 提交记录
public struct MagicGitCommit: Identifiable, Equatable {
    /// 提交哈希（唯一标识）
    public let id: String
    /// 提交哈希
    public let hash: String
    /// 作者名称
    public let author: String
    /// 作者邮箱
    public let email: String
    /// 提交日期
    public let date: Date
    /// 提交信息
    public let message: String
    /// 提交消息的完整内容（包括body）
    public let body: String
    /// 关联的引用（如分支、tag 等）
    public let refs: [String]
    /// 关联的标签名
    public let tags: [String]

    /// 初始化MagicGit提交记录
    public init(id: String, hash: String, author: String, email: String, date: Date, message: String, body: String = "", refs: [String] = [], tags: [String] = []) {
        self.id = id
        self.hash = hash
        self.author = author
        self.email = email
        self.date = date
        self.message = message
        self.body = body
        self.refs = refs
        self.tags = tags
    }

    /// 从MagicGitCommitDetail创建MagicGitCommit
    public init(from detail: MagicGitCommitDetail) {
        self.init(
            id: detail.id,
            hash: detail.id,
            author: detail.author,
            email: detail.email,
            date: detail.date,
            message: detail.message,
            body: detail.body,
            refs: [],
            tags: []
        )
    }
}

/// 表示带标签的提交
public struct CommitWithTag {
    public let hash: String
    public let message: String
    public let tags: [String]

    /// 初始化带标签的提交
    public init(hash: String, message: String, tags: [String]) {
        self.hash = hash
        self.message = message
        self.tags = tags
    }
}


// MARK: - Co-Authored-By Support

/// Git提交中的Co-Authored-By功能支持
///
/// ## 使用示例:
///
/// ```swift
/// // 创建包含Co-Authored-By信息的提交
/// let commit = MagicGitCommit(
///     id: "abc123",
///     hash: "abc123",
///     author: "John Doe",
///     email: "john@example.com",
///     date: Date(),
///     message: "Add new feature",
///     body: """
///     Add new feature implementation
///
///     Co-Authored-By: Jane Smith <jane@example.com>
///     Co-Authored-By: Bob Johnson <bob@example.com>
///     """
/// )
///
/// // 获取共同作者
/// let coAuthors = commit.coAuthors  // ["Jane Smith", "Bob Johnson"]
///
/// // 获取所有作者（格式化字符串）
/// let allAuthors = commit.allAuthors  // "John Doe + Jane Smith + Bob Johnson"
/// ```
///
/// ## 支持的格式:
/// - `Co-Authored-By: Name <email>`
/// - `Co-Authored-By: Name` (无邮箱)
/// - `co-authored-by:` (大小写不敏感)
///
public extension MagicGitCommit {
    /// 从提交消息中解析的共同作者列表
    var coAuthors: [String] {
        parseCoAuthors(from: body.isEmpty ? message : body)
    }

    /// 所有作者的格式化字符串（主要作者 + 共同作者）
    var allAuthors: String {
        let all = [author] + coAuthors
        return all.joined(separator: " + ")
    }

    /// 解析Co-Authored-By信息的私有方法
    /// - Parameter text: 要解析的文本
    /// - Returns: 共同作者名称数组
    private func parseCoAuthors(from text: String) -> [String] {
        let lines = text.split(separator: "\n")
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().starts(with: "co-authored-by:") {
                // 解析 "Co-Authored-By: Name <email>" 格式
                let authorPart = trimmed.dropFirst("Co-Authored-By:".count).trimmingCharacters(in: .whitespaces)
                // 提取姓名部分（去掉邮箱）
                if let angleBracketIndex = authorPart.firstIndex(of: "<") {
                    let name = authorPart[..<angleBracketIndex].trimmingCharacters(in: .whitespaces)
                    return name.isEmpty ? nil : name
                }
                return authorPart
            }
            return nil
        }
    }
}

/// 提交详细信息
public struct MagicGitCommitDetail {
    public let id: String
    public let author: String
    public let email: String
    public let date: Date
    public let message: String
    public let body: String
    public let files: [MagicGitDiffFile]
    public let diff: String

    /// 初始化MagicGit提交详细信息
    public init(id: String, author: String, email: String, date: Date, message: String, body: String, files: [MagicGitDiffFile], diff: String) {
        self.id = id
        self.author = author
        self.email = email
        self.date = date
        self.message = message
        self.body = body
        self.files = files
        self.diff = diff
    }
}

// MARK: - Co-Authored-By Support for MagicGitCommitDetail

/// MagicGitCommitDetail的Co-Authored-By功能支持
///
/// 提供与GitCommit相同的Co-Authored-By解析功能，
/// 用于详细的提交信息展示。
///
/// ## 使用示例:
///
/// ```swift
/// // 获取详细提交信息
/// let detail = try await ShellGit.commitDetail("abc123")
///
/// // 获取共同作者
/// let coAuthors = detail.coAuthors  // ["Jane Smith", "Bob Johnson"]
///
/// // 获取所有作者（格式化字符串）
/// let allAuthors = detail.allAuthors  // "John Doe + Jane Smith + Bob Johnson"
/// ```
///
public extension MagicGitCommitDetail {
    /// 从提交消息body中解析的共同作者列表
    var coAuthors: [String] {
        parseCoAuthors(from: body)
    }

    /// 所有作者的格式化字符串（主要作者 + 共同作者）
    var allAuthors: String {
        let all = [author] + coAuthors
        return all.joined(separator: " + ")
    }

    /// 解析Co-Authored-By信息的私有方法
    /// - Parameter text: 要解析的文本
    /// - Returns: 共同作者名称数组
    private func parseCoAuthors(from text: String) -> [String] {
        let lines = text.split(separator: "\n")
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().starts(with: "co-authored-by:") {
                // 解析 "Co-Authored-By: Name <email>" 格式
                let authorPart = trimmed.dropFirst("Co-Authored-By:".count).trimmingCharacters(in: .whitespaces)
                // 提取姓名部分（去掉邮箱）
                if let angleBracketIndex = authorPart.firstIndex(of: "<") {
                    let name = authorPart[..<angleBracketIndex].trimmingCharacters(in: .whitespaces)
                    return name.isEmpty ? nil : name
                }
                return authorPart
            }
            return nil
        }
    }
}