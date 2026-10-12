import CisumUIComponents
import LumiUI
import OSLog
import SwiftUI

public struct ResetConfirm: View {
    nonisolated static let closeButtonLabel = String(
        localized: "Close",
        bundle: .module
    )

    @Environment(\.dismiss) private var dismiss

    @State private var isResetting = false

    private let resetSettings: ResetSettingsAction

    public init(resetSettings: @escaping ResetSettingsAction) {
        self.resetSettings = resetSettings
    }

    nonisolated static func shouldDisableInteractiveDismiss(isResetting: Bool) -> Bool {
        isResetting
    }

    public var body: some View {
        VStack(spacing: 40) {
            HStack {
                Spacer()
                if !isResetting {
                    closeButton
                }
            }
            .padding(.top, 8)
            .padding(.trailing, 8)

            VStack(spacing: 16) {
                AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                    VStack(spacing: 16) {
                        AppSheetIconHeader(
                            systemImage: .cisumIconReset,
                            title: String(localized: "Reset Storage Location", bundle: .module),
                            tint: .orange
                        )

                        if isResetting {
                            AppStatusBanner(
                                kind: .loading,
                                title: String(localized: "Resetting…", bundle: .module),
                                message: String(localized: "Restoring storage selection, please wait", bundle: .module)
                            )
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                AppInfoRow(
                                    icon: "externaldrive.fill",
                                    title: String(localized: "Storage Location Reset", bundle: .module),
                                    description: String(localized: "The media storage selection will be cleared", bundle: .module),
                                    tint: .orange
                                )

                                AppInfoRow(
                                    icon: "slider.horizontal.3",
                                    title: String(localized: "Preferences Kept", bundle: .module),
                                    description: String(localized: "Playback, theme, and library records are not deleted", bundle: .module),
                                    tint: .orange
                                )

                                AppInfoRow(
                                    icon: "exclamationmark.triangle.fill",
                                    title: String(localized: "Irreversible", bundle: .module),
                                    description: String(localized: "This action cannot be undone, proceed with caution", bundle: .module),
                                    tint: .orange
                                )
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }

                AppButton(
                    String(localized: "Continue Reset", bundle: .module),
                    systemImage: "checkmark",
                    style: .primary,
                    fillsWidth: true
                ) {
                    performReset()
                }
                .cisumIf(!isResetting)
            }
            .cisumVStackCenter()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .background(Self.backgroundColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .interactiveDismissDisabled(Self.shouldDisableInteractiveDismiss(isResetting: isResetting))
    }

    private static var backgroundColor: Color {
        #if os(macOS)
            Color(nsColor: .windowBackgroundColor)
        #else
            Color(uiColor: .systemBackground)
        #endif
    }

    private func performReset() {
        guard !isResetting else { return }

        isResetting = true

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await resetSettings()

            await MainActor.run {
                dismiss()
            }
        }
    }

    private var closeButton: some View {
        Image.cisumClose
            .font(.system(size: 20, weight: .medium))
            .frame(width: 32, height: 32)
            .foregroundStyle(.secondary)
            .background(.regularMaterial, in: Circle())
            .cisumShadowSm()
            .cisumButton {
                dismiss()
            }
            .accessibilityLabel(Self.closeButtonLabel)
            .help(Self.closeButtonLabel)
            .cisumHoverScale(105)
    }
}
