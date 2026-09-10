import CisumUIComponents
import ProviderBook
import ProviderBook
import SwiftUI

/**
 * 用途：展示书籍仓库的状态提示信息
 * 属性说明：
 *   - variant: 提示类型（empty: 空状态, loading: 加载中）
 * 使用场景：在书籍列表为空或正在加载时显示友好的提示界面
 */
struct BookDBTips: View {
    enum Variant {
        case empty
        case loading
    }

    @Environment(\.bookDBViewDependencies) private var dependencies
    @Environment(\.bookDBImportAction) private var requestImport
    @LumiTheme private var appTheme
    var variant: Variant = .empty

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
        .cisumRoundedMedium()
        .shadow(radius: 8)
    }
}

// MARK: - Preview



#if os(macOS)

#endif
