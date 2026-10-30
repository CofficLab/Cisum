import LumiUI
import SwiftUI
import ProviderAudioLibrary

struct AudioDBTips: View {
    enum Variant: Equatable {
        case empty
        case loading
        case sorting
    }

    @LumiTheme private var appTheme
    let dependencies: AudioDBDependencies
    var variant: Variant = .empty
    var sortingMessage: String?
    /// 是否正有文件被拖到本区域上方：用于高亮拖放目标。
    var isDropping: Bool = false

    init(
        dependencies: AudioDBDependencies,
        variant: Variant = .empty,
        sortingMessage: String? = nil,
        isDropping: Bool = false
    ) {
        self.dependencies = dependencies
        self.variant = variant
        self.sortingMessage = sortingMessage
        self.isDropping = isDropping
    }

    var supportedFormats: String {
        dependencies.supportedExtensions.joined(separator: ",")
    }

    var body: some View {
        VStack(spacing: 20) {
            switch variant {
            case .empty:
                AppEmptyState(
                    icon: "music.note.list",
                    title: dependencies.isDesktop
                        ? String(localized: "Drop music files here to add them", bundle: .module)
                        : String(localized: "Music repository is empty", bundle: .module),
                    description: String(localized: "Supported formats: \(supportedFormats)", bundle: .module)
                )
                .frame(minHeight: 160)

                #if os(macOS)
                    if let disk = dependencies.audioDisk() {
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

                BtnAdd(dependencies: dependencies)
                    .buttonStyle(.bordered)

            case .loading:
                AppLoadingOverlay(message: LocalizedStringKey(String(localized: "Reading repository", bundle: .module)), size: .large)
                    .frame(height: 120)
                Text("Supported formats: \(supportedFormats)", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

            case .sorting:
                AppLoadingOverlay(
                    message: LocalizedStringKey(sortingMessage ?? String(localized: "Sorting", bundle: .module)),
                    size: .large
                )
                    .frame(height: 120)
                Text("Supported formats: \(supportedFormats)", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(appTheme.surface.opacity(0.85))
        .background(appTheme.background.opacity(0.5))
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
