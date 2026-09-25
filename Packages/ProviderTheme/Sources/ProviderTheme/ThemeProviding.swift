import CisumUIComponents
import Foundation
import SwiftUI

@MainActor
public enum ThemeProvidingEvent {
    case themesChanged([LumiUIThemeContribution])
    case selectionChanged(String)
}

@MainActor
public protocol ThemeProvidingObserverHandle: AnyObject {
    func cancel()
}

/// 主题服务能力协议。
///
/// 吸收旧版 `ThemeVM` + `ThemeService` + `LumiUIThemeRegistry` 的编排职责：
/// 聚合插件主题贡献、按插件 `order` 重写 `sortKey` 并去重、持久化选中的主题、
/// 将结果同步到 CisumUI 的主题注册中心。
///
/// ## 使用示例
///
/// ```swift
/// kernel.resolveProvider((any ThemeProviding).self)?.selectTheme("cisum")
/// let scheme = kernel.resolveProvider((any ThemeProviding).self)?.preferredColorScheme
/// kernel.resolveProvider((any ThemeProviding).self)?.syncToCisumUI()
/// ```
@MainActor
public protocol ThemeProviding: AnyObject, ObservableObject {
    /// 所有可用主题贡献（已排序、去重）。
    var allThemeContributions: [LumiUIThemeContribution] { get }

    /// 当前选中主题标识符。
    var selectedThemeID: String { get }

    /// 当前生效的 chrome 主题。
    var activeChromeTheme: any LumiAppChromeTheme { get }

    /// 当前主题推导出的 SwiftUI 色彩方案（跟随系统时为 `nil`）。
    var preferredColorScheme: ColorScheme? { get }

    /// 选中一个主题并持久化。
    func selectTheme(_ themeID: String)

    /// 重新从插件聚合主题贡献。
    func reloadThemes()

    /// 将主题状态同步到 CisumUI 主题注册中心（`LumiUIThemeRegistry`）。
    func syncToCisumUI()

    @discardableResult
    func addObserver(_ callback: @escaping (ThemeProvidingEvent) -> Void) -> any ThemeProvidingObserverHandle
}

public extension ThemeProviding {
    @discardableResult
    func addObserver(_ callback: @escaping (ThemeProvidingEvent) -> Void) -> any ThemeProvidingObserverHandle {
        NoopThemeProvidingObserverHandle()
    }
}

@MainActor
public final class NoopThemeProvidingObserverHandle: ThemeProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}
