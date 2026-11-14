import Foundation

/// 表示一个 Git 分支
public struct MagicGitBranch: Identifiable, Equatable, Hashable {
    /// 分支名（唯一标识）
    public let id: String
    /// 分支名
    public let name: String
    /// 是否为当前分支
    public let isCurrent: Bool
    /// 上游分支名（如有）
    public let upstream: String?
    /// 最新提交哈希
    public let latestCommitHash: String
    /// 最新提交信息
    public let latestCommitMessage: String

    /// 初始化MagicGit分支
    public init(id: String, name: String, isCurrent: Bool, upstream: String? = nil, latestCommitHash: String, latestCommitMessage: String) {
        self.id = id
        self.name = name
        self.isCurrent = isCurrent
        self.upstream = upstream
        self.latestCommitHash = latestCommitHash
        self.latestCommitMessage = latestCommitMessage
    }
} 
