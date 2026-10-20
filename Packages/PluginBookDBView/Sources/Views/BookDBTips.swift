import LumiUI
import ProviderBook
import SwiftUI

/**
 * 用途：展示书籍仓库的状态提示信息
 * 属性说明：
 *   - variant: 提示类型（empty: 空状态, loading: 加载中）
 * 使用场景：在书籍列表为空或正在加载时显示友好的提示界面
 */
struct BookDBTips: View {
    enum Variant: Equatable {
        case empty
        case loading
    }

    @LumiTheme private var appTheme
    let dependencies: BookDBViewDependencies
    let requestImport: @MainActor @Sendable () -> Void
    var variant: Variant = .empty
    /// 是否正有文件被拖到本区域上方：用于高亮拖放目标。
    var isDropping: Bool = false

    init(
        dependencies: BookDBViewDependencies,
        requestImport: @escaping @MainActor @Sendable () -> Void,
        variant: Variant = .empty,
        isDropping: Bool = false
    ) {
        self.dependencies = dependencies
        self.requestImport = requestImport
        self.variant = variant
        self.isDropping = isDropping
    }

    var supportedFormats: String {
        BookPluginInfo.supportedExtensions.joined(separator: ",")
    }

    var body: some View {
        VStack(spacing: 20) {
            switch variant {
            case .empty:
                AppEmptyState(
                    icon: "book.closed",
                    title: dependencies.isDesktop
                        ? String(localized: "Drop audiobook folders here to add them", bundle: .module)
                        : String(localized: "Repository is empty", bundle: .module),
                    description: String(localized: "Supported formats: \(supportedFormats)", bundle: .module)
                )
                .frame(minHeight: 160)

                #if os(macOS)
                    if let disk = dependencies.bookDisk {
                        Text("Or", bundle: .module)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        AppButton(
                            String(localized: "Open repository folder and add files", bundle: .module),
                            systemImage: "doc.viewfinder.fill",
                            style: .secondary,
                            size: .small
                        ) {
                            disk.openFolder()
                        }
                    }
                #endif

                if dependencies.isNotDesktop {
                    Button(
                        action: requestImport,
                        label: {
                            Label(
                                title: { Text("Add", bundle: .module) },
                                icon: { Image(systemName: "plus.circle") }
                            )
                        }
                    )
                    .buttonStyle(.bordered)
                }
            case .loading:
                AppLoadingOverlay(message: LocalizedStringKey(String(localized: "Reading repository", bundle: .module)), size: .large)
                    .frame(height: 120)
                Text("Supported formats: \(supportedFormats)", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(appTheme.surface.opacity(0.85))
        // 空状态铺满整个内容区，圆角会在窗口左右上角露出背景缺口，
        // 因此这里保持直角；阴影只用于衬托圆角卡片，一并去掉。
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            // 空状态是本视图的拖放目标，用虚线描边标出可接收文件的区域。
            if variant == .empty {
                dropZoneBorder
            }
        }
    }

    /// 拖放目标标记：虚线描边；拖拽悬停时高亮，提示"可以松手了"。
    private var dropZoneBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(
                appTheme.primary.opacity(isDropping ? 1 : 0.45),
                style: StrokeStyle(lineWidth: 2, dash: [8, 6])
            )
            // 留 8pt：内容自带 16pt 内边距，避免按钮压到虚线上。
            .padding(8)
    }
}

// MARK: - Preview



#if os(macOS)

#endif
