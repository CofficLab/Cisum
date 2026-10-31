import LumiUI
import SwiftUI

public struct WelcomeView: View {
    @LumiTheme private var appTheme
    private let isICloudAvailable: Bool
    private let currentStorageSelection: WelcomeStorageSelection?
    private let updateStorageSelection: @MainActor (WelcomeStorageSelection) -> Void

    public init(
        isICloudAvailable: Bool,
        currentStorageSelection: WelcomeStorageSelection?,
        updateStorageSelection: @escaping @MainActor (WelcomeStorageSelection) -> Void
    ) {
        self.isICloudAvailable = isICloudAvailable
        self.currentStorageSelection = currentStorageSelection
        self.updateStorageSelection = updateStorageSelection
    }

    public var body: some View {
        GeometryReader { geometry in
            // 内容高度随窗口高度自适应：窗口偏矮时收紧留白与标题字号，
            // 否则「继续」按钮会被挤出窗口底部——用户看得见存储选项却
            // 按不到确认按钮，首启引导就成了死路。
            let metrics = WelcomeLayoutMetrics(height: geometry.size.height)
            VStack(spacing: metrics.sectionSpacing) {
                Spacer(minLength: 0)

                VStack(spacing: metrics.itemSpacing) {
                    Image(systemName: "sparkles")
                        .font(.system(size: metrics.iconSize, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(appTheme.primary)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 8)

                    Text("Choose Your Media Storage", bundle: .module)
                        .font(.system(size: metrics.titleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(appTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .accessibilityAddTraits(.isHeader)

                    Text("Choose where Cisum stores your music and audiobooks. You can change this later in Settings.", bundle: .module)
                        .font(.title3)
                        .foregroundStyle(appTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.top, metrics.itemSpacing)

                    StorageView(
                        isICloudAvailable: isICloudAvailable,
                        currentStorageSelection: currentStorageSelection,
                        updateStorageSelection: updateStorageSelection
                    )
                    .background(.regularMaterial)
                    .appRoundedMedium()
                    .shadowSm()

                }

                Spacer(minLength: 0)
            }
            .padding(metrics.outerPadding)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

/// 首启引导页的尺寸档位。
///
/// 引导页要在**任意窗口高度**下都完整可见——尤其是「继续」按钮：
/// 它是引导流程唯一的出口，按不到就等于首启死路。窗口偏矮时按比例
/// 收紧留白与标题字号，让内容总高度落回可用高度内。
struct WelcomeLayoutMetrics {
    /// 常规档（窗口足够高）。
    static let regular = WelcomeLayoutMetrics(
        outerPadding: 24,
        sectionSpacing: 24,
        itemSpacing: 12,
        iconSize: 48,
        titleSize: 34
    )

    /// 紧凑档（窗口偏矮）。
    static let compact = WelcomeLayoutMetrics(
        outerPadding: 12,
        sectionSpacing: 10,
        itemSpacing: 6,
        iconSize: 32,
        titleSize: 26
    )

    /// 窗口高度低于此值时切换到紧凑档。
    static let compactHeightThreshold: CGFloat = 860

    let outerPadding: CGFloat
    let sectionSpacing: CGFloat
    let itemSpacing: CGFloat
    let iconSize: CGFloat
    let titleSize: CGFloat

    init(
        outerPadding: CGFloat,
        sectionSpacing: CGFloat,
        itemSpacing: CGFloat,
        iconSize: CGFloat,
        titleSize: CGFloat
    ) {
        self.outerPadding = outerPadding
        self.sectionSpacing = sectionSpacing
        self.itemSpacing = itemSpacing
        self.iconSize = iconSize
        self.titleSize = titleSize
    }

    /// 按窗口高度选择尺寸档位。
    init(height: CGFloat) {
        self = height < Self.compactHeightThreshold ? Self.compact : Self.regular
    }
}
