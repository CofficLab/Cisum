import CisumUIComponents
import SwiftUI
import ProviderAudioLibrary

struct AudioDBTips: View {
    enum Variant {
        case empty
        case loading
        case sorting
    }

    @LumiTheme private var appTheme
    let dependencies: AudioDBDependencies
    var variant: Variant = .empty
    var sortingMessage: String?

    init(
        dependencies: AudioDBDependencies,
        variant: Variant = .empty,
        sortingMessage: String? = nil
    ) {
        self.dependencies = dependencies
        self.variant = variant
        self.sortingMessage = sortingMessage
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
                    .cisumIf(dependencies.isNotDesktop)

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
        .cisumRoundedMedium()
        .cisumShadowXl()
    }
}

// MARK: - Preview
