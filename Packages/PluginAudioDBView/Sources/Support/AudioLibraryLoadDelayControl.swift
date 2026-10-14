import Foundation

/// UI 测试用的音频库首屏加载延迟开关。
///
/// 骨架屏只在 `isLoading && urls.isEmpty` 时出现；本地仓库只有一两条种子音频时，
/// 首屏不到 1s 就加载完成，XCUITest 的可访问性轮询（约 0.3-0.5s 一轮）根本没有
/// 稳定窗口去观测骨架几何。这里让 UI 测试用启动参数把首屏加载**延后**若干秒，
/// 骨架因而稳定停留在屏幕上，几何断言才可复现。
///
/// 遵循 MagicKit `ICloudDownloadControl` 的既有惯例：启动参数形如
/// `--cisum-ui-testing-audio-load-delay=5`，无参数或参数非法时不安装任何覆写，
/// 生产行为完全不变。
enum AudioLibraryLoadDelayControl {
    /// UI 测试使用的启动参数键，形如 `--cisum-ui-testing-audio-load-delay=5`。
    static let launchArgumentKey = "--cisum-ui-testing-audio-load-delay"

    /// 上限：避免参数写错时把首屏卡住过久，让 UI 测试长时间停在骨架屏。
    private static let maximumDelay: TimeInterval = 30

    /// 首屏加载前的额外等待时长；`nil` 表示不延迟（生产路径）。
    static func firstPageDelay(arguments: [String] = ProcessInfo.processInfo.arguments) -> TimeInterval? {
        guard let raw = arguments.first(where: { $0.hasPrefix(launchArgumentKey) }) else {
            return nil
        }

        let value = String(raw.dropFirst(launchArgumentKey.count))
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
            .trimmingCharacters(in: .whitespaces)

        guard let seconds = Double(value), seconds.isFinite, seconds > 0 else {
            // 坏参数不静默变成「不延迟」，否则测试会以「骨架没出现」的形式失败，
            // 掩盖真正的原因。
            return nil
        }

        return min(seconds, maximumDelay)
    }
}