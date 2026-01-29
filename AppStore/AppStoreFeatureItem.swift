import MagicKit
import SwiftUI

/// App Store 功能特性项视图
/// 统一的组件，用于展示功能特性，支持多种样式变体
struct AppStoreFeatureItem: View {
    let icon: String
    let title: String
    let description: String
    
    // 可选参数，支持不同的样式变体
    var color: Color? = nil
    var iconGradient: LinearGradient? = nil
    var showIconBackground: Bool = false
    var showBorder: Bool = false
    var width: CGFloat = 380
    var iconSize: CGFloat = 24
    var iconContainerSize: CGFloat = 44
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标部分
            iconView
                .frame(width: iconContainerSize)
            
            // 文本部分
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(16)
        .frame(width: width)
        .background(backgroundView)
        .overlay(borderView)
    }
    
    // MARK: - Icon View
    
    @ViewBuilder
    private var iconView: some View {
        if showIconBackground, let color = color {
            // 带圆形背景的图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: iconContainerSize, height: iconContainerSize)
                
                Image(systemName: icon)
                    .font(.system(size: iconSize))
                    .foregroundStyle(color)
            }
        } else if let gradient = iconGradient {
            // 使用渐变的图标
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundStyle(gradient)
        } else if let color = color {
            // 使用纯色的图标
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundStyle(color)
        } else {
            // 默认样式：使用渐变的图标
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - Background View
    
    @ViewBuilder
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.regularMaterial)
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
    
    // MARK: - Border View
    
    @ViewBuilder
    private var borderView: some View {
        if showBorder, let color = color {
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        }
    }
}

// MARK: - Convenience Initializers

extension AppStoreFeatureItem {
    /// 创建带圆形背景和边框的特性项（用于 iCloud 等场景）
    /// - Parameters:
    ///   - icon: 图标名称
    ///   - title: 标题
    ///   - description: 描述
    ///   - color: 主题颜色
    static func withBackground(
        icon: String,
        title: String,
        description: String,
        color: Color
    ) -> AppStoreFeatureItem {
        AppStoreFeatureItem(
            icon: icon,
            title: title,
            description: description,
            color: color,
            showIconBackground: true,
            showBorder: true
        )
    }
    
    /// 创建带圆形背景的特性项（用于专辑封面等场景）
    /// - Parameters:
    ///   - icon: 图标名称
    ///   - title: 标题
    ///   - description: 描述
    ///   - color: 主题颜色
    static func withCircleIcon(
        icon: String,
        title: String,
        description: String,
        color: Color
    ) -> AppStoreFeatureItem {
        AppStoreFeatureItem(
            icon: icon,
            title: title,
            description: description,
            color: color,
            showIconBackground: true,
            showBorder: false
        )
    }
    
    /// 创建使用渐变的特性项（用于极简设计等场景）
    /// - Parameters:
    ///   - icon: 图标名称
    ///   - title: 标题
    ///   - description: 描述
    ///   - gradient: 图标渐变（可选）
    static func withGradient(
        icon: String,
        title: String,
        description: String,
        gradient: LinearGradient? = nil
    ) -> AppStoreFeatureItem {
        AppStoreFeatureItem(
            icon: icon,
            title: title,
            description: description,
            iconGradient: gradient ?? LinearGradient(
                colors: [.blue, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            width: 360
        )
    }
}

// MARK: - Preview

#Preview("With Background & Border") {
    VStack(spacing: 16) {
        AppStoreFeatureItem.withBackground(
            icon: "icloud",
            title: "云端同步",
            description: "音乐库实时同步，随时随地访问",
            color: .blue
        )
        
        AppStoreFeatureItem.withCircleIcon(
            icon: "photo.fill",
            title: "高清封面",
            description: "自动获取专辑封面，无需手动添加",
            color: .purple
        )
        
        AppStoreFeatureItem.withGradient(
            icon: "trash",
            title: "没有广告",
            description: "纯净体验，专注音乐"
        )
    }
    .padding()
}
