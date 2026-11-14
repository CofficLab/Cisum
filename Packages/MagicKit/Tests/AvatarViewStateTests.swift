import Foundation
import Testing
@testable import MagicKit

// MARK: - 头像的初判错误

/// 本地不存在的文件不得被初判成错误。
///
/// iCloud 占位文件在下载完成前本地并不存在，但它不是错误——缩略图生成器会把它
/// 解析成「云端未下载」图标。初判成错误会让红色感叹号压在任何下载态下面。
@Test func missingLocalFileIsNotPresumedToBeAnError() {
    let missing = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("cisum-avatar-missing-\(UUID().uuidString).mp3")

    #expect(AvatarView.initialError(for: missing) == nil)
}

/// URL 根本不是文件也不是网络地址时，错误无需 I/O 即可判定。
@Test func nonFileNonNetworkURLIsStillAnInvalidURL() {
    let url = URL(string: "cisum://not-a-real-scheme/track")!

    guard case .invalidURL = AvatarView.initialError(for: url) else {
        Issue.record("非文件非网络 URL 应当被初判为 invalidURL")
        return
    }
}

/// 正常的文件 URL 不得带初判错误。
@Test func fileURLHasNoPresumedError() {
    let file = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("cisum-avatar-file-\(UUID().uuidString).mp3")

    #expect(AvatarView.initialError(for: file) == nil)
}

// MARK: - 结论标记

/// 错误态只有在「已有结论」之后才允许渲染。
///
/// 没有结论时视图给加载态，而不是先把红色感叹号画出来。
@MainActor
@Test func errorStateIsHiddenUntilResolved() {
    let state = AvatarView.ViewState(error: AvatarView.ViewError.fileNotFound)

    #expect(state.isResolved == false)
    #expect(state.error != nil)

    state.setResolved(true)
    #expect(state.isResolved == true)
}

/// 重置状态意味着「回到未解析」，错误态必须重新被挡住。
@MainActor
@Test func resetClearsResolutionAndError() {
    let state = AvatarView.ViewState(error: AvatarView.ViewError.fileNotFound)
    state.setResolved(true)

    state.reset()

    #expect(state.isResolved == false)
    #expect(state.error == nil)
}

/// 标记为需要重载时同样回到未解析态：重载期间不该闪出旧错误。
@MainActor
@Test func markingNeedsReloadClearsResolution() {
    let state = AvatarView.ViewState(error: AvatarView.ViewError.fileNotFound)
    state.setResolved(true)

    state.markNeedsReload()

    #expect(state.isResolved == false)
    #expect(state.needsReload == true)
}
