import CoreGraphics

/// 根布局：几何尺寸变化后，内容区（音乐库）是否应被收起为「纯播放器」态的判定。
///
/// 抽出为纯函数以便单测覆盖平台差异；`CisumRootLayoutView.handleGeometryChange`
/// 通过注入编译期平台常量调用它。
enum RootContentVisibility {
    /// 宿主是否为 macOS。生产路径注入此值；测试可传入任意平台以覆盖两条分支。
    static var hostIsMacOS: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    static func shouldHideContentView(
        isMacOS: Bool,
        newHeight: CGFloat,
        dropThreshold: CGFloat
    ) -> Bool {
        // 「窗口拉矮就丢弃副栏」是 macOS 桌面窗口的响应式规则。iOS 上根视图高度
        // 恒等于屏幕，启动 / 旋转 / safe-area 过渡期间的瞬时小值会把音乐库永久收起
        // 且无自动恢复路径（内容区显隐在 iOS 上应完全由用户通过控制按钮切换），
        // 因此该规则仅在 macOS 生效。
        guard isMacOS else { return false }
        return newHeight <= dropThreshold
    }
}
