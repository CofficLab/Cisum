import CisumUIComponents
import MagicKit
import LumiUI
import OSLog
import StoreKit
import SwiftUI

struct RestoreView: View, SuperEvent, SuperLog, SuperThread {
    @LumiTheme private var appTheme
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var subscriptions: [Product] = []
    @State private var refreshing = false
    @State private var error: Error? = nil
    @State private var restoreState: RestoreState = .idle

    nonisolated static let emoji = "🖥️"
    nonisolated static let verbose = false

    init() {}

    var body: some View {
        SheetContainer {
            VStack(spacing: 16) {
                // Description text.
                AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                    VStack(spacing: 16) {
                        AppSheetIconHeader(systemImage: "icloud.and.arrow.down.fill", title: localized("Restore Purchase"), tint: appTheme.primary)
                        VStack(alignment: .leading, spacing: 12) {
                            AppInfoRow(
                                icon: "iphone.and.arrow.forward",
                                title: localized("Cross-Device Restore"),
                                description: localized("Restore purchases made on other devices"),
                                tint: appTheme.primary
                            )

                            AppInfoRow(
                                icon: "person.circle",
                                title: localized("Apple ID Verification"),
                                description: localized("Use the same Apple ID used for purchase"),
                                tint: appTheme.primary
                            )

                            AppInfoRow(
                                icon: "checkmark.circle",
                                title: localized("Feature Restore"),
                                description: localized("Get all purchased features after successful restore"),
                                tint: appTheme.primary
                            )
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Status banner area
                if restoreState != .idle {
                    statusBanner
                }

                // Button area
                successButtons
                    .cisumIf(self.restoreState == .success)

                restoreButton
                    .cisumIf(self.restoreState == .failed || self.restoreState == .idle)
            }.cisumVStackCenter()
        }
    }

    // MARK: - View

    @ViewBuilder
    private var statusBanner: some View {
        switch restoreState {
        case .idle:
            EmptyView()
        case .restoring:
            AppStatusBanner(kind: .loading, title: localized("Restoring Purchase"), message: localized("Please wait, verifying your purchase records..."))
        case .success:
            AppStatusBanner(kind: .success, title: localized("Restore Successful"), message: localized("Successfully restored your purchase records, all features unlocked"))
        case .failed:
            AppStatusBanner(kind: .error, title: localized("Restore Failed"), message: error?.localizedDescription ?? localized("An error occurred while restoring, please try again later"))
        }
    }

    @ViewBuilder
    private var restoreButton: some View {
        AppButton(
            restoreState == .failed ? localized("Retry Restore") : localized("Restore Purchase"),
            systemImage: "arrow.clockwise",
            style: .primary,
            fillsWidth: true
        ) {
            restorePurchase()
        }
        .disabled(restoreState == .restoring)
    }

    @ViewBuilder
    private var successButtons: some View {
        HStack(spacing: 12) {
            AppButton(localized("Done"), systemImage: "checkmark.circle.fill", style: .primary, fillsWidth: true) {
                dismiss()
            }

            AppButton(localized("Try Again"), systemImage: "arrow.clockwise", style: .primary, fillsWidth: true) {
                restoreState = .idle
                restorePurchase()
            }
        }
    }

    // MARK: - Actions

    private func restorePurchase() {
        restoreState = .restoring
        error = nil // Clear the previous error.
        Task {
            do {
                if Self.verbose {
                    os_log("\(self.t)🚀 Starting purchase restore")
                }
                try await AppStore.sync()
                if Self.verbose {
                    os_log("\(self.t)✅ Purchase restore completed")
                }
                await MainActor.run {
                    restoreState = .success
                    error = nil // Clear error information.
                    postRestore()
                }
            } catch {
                await MainActor.run {
                    restoreState = .failed
                    self.error = error
                    if Self.verbose {
                        os_log("\(self.t)❌ Purchase restore failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

private extension RestoreView {
    func localized(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }
}

// MARK: - Types

/// Purchase restore state.
private enum RestoreState {
    case idle // Before restore.
    case restoring // Restore in progress.
    case success // Restore succeeded.
    case failed // Restore failed.
}

// MARK: - Supporting Views

// MARK: - Event Emitter

extension RestoreView {
    func postRestore() {
        NotificationCenter.default.post(name: .Restored, object: nil)
    }
}
