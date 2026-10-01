import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

/// 喜欢按钮视图
///
/// 这是一个自观察的按钮视图，会自动监听 MagicPlayMan 的喜欢状态变化。
/// 根据当前媒体资源的喜欢状态显示不同的图标和样式，支持喜欢/取消喜欢操作。
///
/// ## 特性
/// - 自动响应喜欢状态变化
/// - 动态图标和样式切换（实心/空心爱心）
/// - 支持自定义按钮尺寸
/// - 智能禁用状态管理
/// - 异步操作处理
///
/// ## 使用示例
/// ```swift
/// // 基础用法
/// LikeButtonView(man: playMan, size: 28)
/// ```
///
/// - Parameters:
///   - man: MagicPlayMan 实例，用于监听喜欢状态和触发喜欢操作
///   - size: 按钮尺寸，默认为 28
struct LikeButtonView: View {
    @ObservedObject var man: MagicPlayMan
    let size: CGFloat

    /// 初始化方法
    init(
        man: MagicPlayMan,
        size: CGFloat = 28
    ) {
        self.man = man
        self.size = size
    }

    @Environment(\.localization) private var loc

    var body: some View {
        Button(action: { man.toggleLike() }) {
            Image(systemName: man.isCurrentAssetLiked ? "heart.fill" : "heart")
                .symbolVariant(man.isCurrentAssetLiked ? .fill : .none)
                .foregroundStyle(man.isCurrentAssetLiked ? .red : .primary)
                .frame(width: size, height: size)
        }
        .disabled(!man.hasAsset)
        .buttonStyle(.borderless)
        .accessibilityLabel(man.isCurrentAssetLiked ? loc.unlikeCurrentMedia : loc.likeCurrentMedia)
        .help(man.hasAsset ? (man.isCurrentAssetLiked ? loc.unlikeCurrentMedia : loc.likeCurrentMedia) : loc.noMediaLoaded)
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayMan
        .getPreviewView()
        .frame(height: 600)
}
