import Foundation
import Testing
@testable import PluginAudioDBView

/// 头像呈现策略：哪些进度值算「进行中的下载」。
///
/// 只有 `0 < progress < 1` 才渲染进度环；`0` 表示没有下载记录、`1` 表示已完成，
/// 两者都要把位置让给封面。
@Test func activeProgressOnlyForInFlightDownloads() {
    #expect(AudioItemAvatarPolicy.activeProgress(0.5) == 0.5)
    #expect(AudioItemAvatarPolicy.activeProgress(0.01) == 0.01)
    #expect(AudioItemAvatarPolicy.activeProgress(0.99) == 0.99)
}

/// 没有下载记录（0）与已经完成（1）都不是进行中的下载。
@Test func activeProgressIsNilWhenNotDownloading() {
    #expect(AudioItemAvatarPolicy.activeProgress(0) == nil)
    #expect(AudioItemAvatarPolicy.activeProgress(1) == nil)
}

/// 越界的进度值不得被当成进行中的下载。
@Test func activeProgressRejectsOutOfRangeValues() {
    #expect(AudioItemAvatarPolicy.activeProgress(1.5) == nil)
    #expect(AudioItemAvatarPolicy.activeProgress(-0.2) == nil)
}

/// 头像重建标记必须随下载完成次数变化。
///
/// 下载完成前封面是占位，必须换新 id 强制 `AvatarView` 重建；否则封面一直不刷新。
@Test func avatarIdentityChangesWithReloadToken() {
    let url = URL(fileURLWithPath: "/tmp/cisum-avatar-identity.mp3")

    let before = AudioItemAvatarIdentity(id: url, reloadToken: 0)
    let after = AudioItemAvatarIdentity(id: url, reloadToken: 1)

    #expect(before != after)
    #expect(before == AudioItemAvatarIdentity(id: url, reloadToken: 0))
}
