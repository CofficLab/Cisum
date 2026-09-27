import MagicKit
import CisumUIComponents
import LumiUI
import SwiftUI

public typealias ResetSettingsAction = @Sendable () async -> Void

public struct SystemSetting: View, SuperLog {
    public nonisolated static let emoji = ResetPluginInfo.emoji
    public nonisolated static let verbose = false
    nonisolated static let resetStorageLocationActionLabel = String(
        localized: "Reset Storage Location",
        bundle: .module
    )

    @State private var showConfirmSheet = false

    private let appVersion: String
    private let resetSettings: ResetSettingsAction

    public init(
        appVersion: String,
        resetSettings: @escaping ResetSettingsAction
    ) {
        self.appVersion = appVersion
        self.resetSettings = resetSettings
    }

    public var body: some View {
        AppSettingsContentScaffold {
            VStack(alignment: .leading, spacing: 16) {
                AppSettingSection(title: String(localized: "App Information", bundle: .module)) {
                    AppSettingRow(
                        title: String(localized: "Current Version", bundle: .module),
                        description: String(localized: "App version", bundle: .module),
                        icon: "info.circle",
                        content: {
                            Text(appVersion)
                                .font(.footnote)
                        }
                    )

                    AppSettingRow(
                        title: String(localized: "Reset Storage Location", bundle: .module),
                        description: String(localized: "Clear the media storage selection", bundle: .module),
                        icon: .cisumIconReset
                    ) {
                        Image.cisumReset
                            .frame(width: 28, height: 28)
                            .background(.regularMaterial, in: Circle())
                            .cisumShadowSm()
                            .cisumHoverScale(105)
                            .cisumButton {
                                showConfirmSheet = true
                            }
                            .accessibilityLabel(Self.resetStorageLocationActionLabel)
                            .help(Self.resetStorageLocationActionLabel)
                    }
                }
            }
        }
        .sheet(isPresented: $showConfirmSheet) {
            ResetConfirm(resetSettings: resetSettings)
                .frame(width: 400)
        }
    }
}
