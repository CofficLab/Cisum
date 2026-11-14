import Foundation

/// 音频播放顺序能力。
///
/// 排序的具体持久化方式由数据插件实现；播放模式插件只依赖这个窄协议。
@MainActor
public protocol AudioLibraryOrderingProviding: AnyObject, Sendable {
    func sort(url: URL?, reason: String) async
    func sortRandom(url: URL?, reason: String, verbose: Bool) async throws
}
