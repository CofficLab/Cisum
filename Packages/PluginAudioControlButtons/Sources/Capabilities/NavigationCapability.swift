import Foundation

/// ControlButtons 的曲目导航能力。
///
/// ViewModel 只依赖这个最小边界；具体的 Kernel Providing 由插件入口在
/// `onReady` / `onEnable` 阶段解析并组装。
@MainActor
protocol NavigationCapability: AnyObject {
    func nextURL(after current: URL?) async throws -> URL?
    func previousURL(before current: URL?) async throws -> URL?
    func firstURL() async throws -> URL?
    func lastURL() async throws -> URL?
}
