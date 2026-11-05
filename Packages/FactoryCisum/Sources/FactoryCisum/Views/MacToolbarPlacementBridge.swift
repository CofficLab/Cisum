#if os(macOS)
import AppKit
import SwiftUI

/// macOS 窗口工具栏落位修正桥。
///
/// ## 它修的是什么
///
/// SwiftUI 的 `ToolbarItem(placement:)` 在 macOS 上要落到标题栏的**尾随侧**
/// （窗口右上角），前提是窗口标题**可见**。一旦 `NSWindow.titleVisibility`
/// 为 `.hidden`，SwiftUI 会把整组工具栏项降级为**前导侧**（紧挨红绿灯），
/// 且**所有 placement 一律失效**——`.primaryAction` 与 `.confirmationAction`
/// 实测都落在同一位置。
///
/// 触发隐藏的常见来源有两个，且**各自独立**地造成该降级：
///
/// - `windowStyle(.hiddenTitleBar)`
/// - `windowToolbarStyle(.unified(showsTitle: false))`
///
/// Cisum 主窗口同时用了这两者（`CisumMacApp.swift`），于是插件贡献的
/// 工具栏按钮（设置齿轮、场景切换器）紧贴红绿灯。
///
/// ## 本桥的做法
///
/// 保留「无标题栏」的**外观**（背景延伸到窗口顶部、无分隔线、无标题文字），
/// 同时把 `titleVisibility` 修正回 `.visible`，让 SwiftUI 恢复 placement 语义。
///
/// - `titleVisibility = .visible` —— 恢复 placement 语义的**关键**；
/// - `titlebarAppearsTransparent = true` —— 背景延伸到标题栏，实测**无害**；
/// - `titlebarSeparatorStyle = .none` —— 去掉标题栏下方的分隔线，实测**无害**；
/// - `title = ""` —— 隐藏标题**文字**（否则 "Cisum" 会出现在红绿灯右侧）。
///
/// ## 关于标题文字与无障碍
///
/// `title = ""` 只清掉标题栏里**显示的文字**，窗口的**无障碍标题**另行保留：
/// `setAccessibilityTitle("Cisum")` 让 VoiceOver 仍能读出窗口用途，
/// XCUITest 的 `app.windows["Cisum"]` 也仍然匹配得到（实测 `title` 与
/// `identifier` 均正常暴露）。
///
/// 注意 `Window` 菜单与 Cmd+Tab 用的是**无障碍标题**，因此两者仍显示 "Cisum"，
/// 不受标题文字置空影响。
///
/// ## 为什么不放进插件
///
/// 窗口装饰（`titlebarAppearsTransparent` / `titleVisibility`）属于**宿主**
/// 职责：同一段设置若散落到各插件，插件就反过来依赖了宿主的窗口样式。
/// 插件只负责声明 `.primaryAction`，宿主负责让该声明真正生效。
@MainActor
struct MacToolbarPlacementBridge: NSViewRepresentable {
    /// 窗口标题文字置空后，用于无障碍的替代名称。
    ///
    /// 传 nil 表示不设置（保留 AppKit 默认的 "(untitled)"）。
    let accessibilityTitle: String?

    init(accessibilityTitle: String? = nil) {
        self.accessibilityTitle = accessibilityTitle
    }

    func makeNSView(context: Context) -> NSView {
        let view = MacToolbarPlacementHostView()
        view.updateAccessibilityTitle(accessibilityTitle)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let host = nsView as? MacToolbarPlacementHostView else { return }
        host.updateAccessibilityTitle(accessibilityTitle)
        host.applyPlacement()
    }
}

/// 承载窗口属性修正的宿主视图。
///
/// 用 `viewDidMoveToWindow` 而不是 `makeNSView` 里 `DispatchQueue.main.async`：
/// 前者能覆盖「视图被复用/移动到另一个窗口」的情况，且在窗口就绪的时机上
/// 更可靠（`makeNSView` 时 `view.window` 往往还是 nil）。
private final class MacToolbarPlacementHostView: NSView {
    /// 无障碍替代标题（nil 表示不设置）。
    private var titleForAccessibility: String?

    /// 设置无障碍标题。
    ///
    /// 单独一个 setter 而不是可写属性，是为了避免 `didSet` 触发的隐式
    /// `applyPlacement()`——无障碍标题与窗口装饰是两件事，不该互相牵引。
    func updateAccessibilityTitle(_ title: String?) {
        guard titleForAccessibility != title else { return }
        titleForAccessibility = title
        applyPlacement()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyPlacement()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPlacement()
    }

    /// 把窗口调整成「标题可见但无文字 + 标题栏透明」的外观。
    ///
    /// 幂等：重复调用无副作用。
    func applyPlacement() {
        guard let window else { return }

        // 顺序有讲究：先恢复标题可见性（placement 依赖它），
        // 再处理标题文字与装饰，避免中间态触发多余的标题栏重排。
        if window.titleVisibility != .visible {
            window.titleVisibility = .visible
        }
        if !window.titlebarAppearsTransparent {
            window.titlebarAppearsTransparent = true
        }
        if window.titlebarSeparatorStyle != .none {
            window.titlebarSeparatorStyle = .none
        }

        // 标题文字置空：SwiftUI 会用 Scene 标题回填 `window.title`，
        // 所以这里每次都重新置空，确保视觉上不出现标题文字。
        if !window.title.isEmpty {
            window.title = ""
        }
        // 无障碍名称单独保留，不随标题文字一起消失。
        //
        // 用 `setAccessibilityTitle(_:)` 而非属性赋值：`NSWindow` 自身声明了
        // `accessibilityTitle()` 方法，把 `NSAccessibilityElementProtocol` 的
        // 可写属性 `accessibilityTitle` 遮蔽掉了，直接赋值编译不过。
        if let titleForAccessibility, window.accessibilityTitle() != titleForAccessibility {
            window.setAccessibilityTitle(titleForAccessibility)
        }
    }
}
#endif
