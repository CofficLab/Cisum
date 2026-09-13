import CisumUIComponents
import OSLog
import SwiftUI

public struct StorageSettingView: View, SuperLog {
    public nonisolated static let emoji: String = "🍴"

    @ObservedObject var viewModel: StorageSettingsViewModel
    let dependencies: StorageDependencies
    @State private var showMigrationProgress = false
    @State private var targetLocation: StoragePluginLocation
    @State private var hasChanges = false

    init(viewModel: StorageSettingsViewModel, dependencies: StorageDependencies) {
        self.viewModel = viewModel
        self.dependencies = dependencies
        _targetLocation = State(initialValue: .local)
    }

    public var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            AppSettingSection(title: String(localized: "Media Storage Location", bundle: .module)) {
                VStack(spacing: 0) {
                    AppSettingRow(
                        title: String(localized: "iCloud Drive", bundle: .module),
                        description: viewModel.isICloudAvailable
                            ? String(localized: "Store media files in iCloud Drive", bundle: .module)
                            : String(localized: "iCloud Drive is unavailable", bundle: .module),
                        icon: .cisumIconCloud,
                        action: viewModel.isICloudAvailable ? {
                            beginMigration(to: .icloud)
                        } : nil
                    ) {
                        if viewModel.location == .icloud {
                            Image(systemName: .cisumIconCheckmarkSimple)
                                .foregroundColor(.accentColor)
                        } else if !viewModel.isICloudAvailable {
                            Text("Unavailable", bundle: .module)
                                .font(.footnote)
                        }
                    }
                    .opacity(viewModel.isICloudAvailable ? 1 : 0.5)

                    AppSettingRow(
                        title: String(localized: "Local", bundle: .module),
                        description: viewModel.isLocalStorageAvailable
                            ? String(localized: "Store within app, data will be lost if app is deleted", bundle: .module)
                            : String(localized: "Local storage is unavailable", bundle: .module),
                        icon: .cisumIconFolder,
                        action: viewModel.isLocalStorageAvailable ? {
                            beginMigration(to: .local)
                        } : nil
                    ) {
                        if viewModel.location == .local {
                            Image(systemName: .cisumIconCheckmarkSimple)
                                .foregroundColor(.accentColor)
                        } else if !viewModel.isLocalStorageAvailable {
                            Text("Unavailable", bundle: .module)
                                .font(.footnote)
                        }
                    }
                    .opacity(viewModel.isLocalStorageAvailable ? 1 : 0.5)

                    Divider()

                    AppSettingRow(
                        title: String(localized: "Open Current Repository", bundle: .module),
                        description: viewModel.storageRoot?.path
                            ?? String(localized: "No storage location set", bundle: .module),
                        icon: .cisumIconFolder,
                        action: viewModel.storageRoot.map { _ in openCurrentRepository }
                    ) {
                        Image(systemName: "arrow.up.forward.square")
                            .foregroundColor(.accentColor)
                    }
                    .opacity(viewModel.storageRoot == nil ? 0.5 : 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showMigrationProgress) {
            MigrationProgressView(
                sourceLocation: viewModel.location,
                targetLocation: targetLocation,
                sourceURL: viewModel.storageRoot,
                targetURL: viewModel.storageRoot(for: targetLocation),
                onDismiss: {
                    showMigrationProgress = false
                    self.hasChanges = targetLocation != viewModel.location
                },
                dependencies: dependencies
            )
        }
        .onAppear {
            applyStorageLocationUpdate(viewModel.location)
        }
        .onChange(of: targetLocation) {
            hasChanges = Self.hasSelectionChanges(
                targetLocation: targetLocation,
                storageLocation: viewModel.location
            )
        }
        // 纯派生 UI 状态：ViewModel 的存储位置变化（由 Observer 驱动）同步到
        // 本地的 targetLocation / hasChanges。
        .onChange(of: viewModel.location) { _, newLocation in
            applyStorageLocationUpdate(newLocation)
        }
    }

    private func applyStorageLocationUpdate(_ storageLocation: StoragePluginLocation?) {
        let state = Self.stateAfterStorageUpdate(
            currentTarget: targetLocation,
            storageLocation: storageLocation
        )
        targetLocation = state.targetLocation
        hasChanges = state.hasChanges
    }

    private func beginMigration(to newLocation: StoragePluginLocation) {
        guard newLocation != viewModel.location else { return }
        guard viewModel.storageRoot(for: newLocation) != nil else { return }

        targetLocation = newLocation
        showMigrationProgress = true
    }

    /// 在 Finder 中打开当前媒体仓库（当前存储位置的根目录）。
    private func openCurrentRepository() {
        viewModel.storageRoot?.openFolder()
    }

    nonisolated static func targetLocationAfterStorageUpdate(
        currentTarget: StoragePluginLocation,
        storageLocation: StoragePluginLocation?
    ) -> StoragePluginLocation {
        storageLocation ?? currentTarget
    }

    nonisolated static func stateAfterStorageUpdate(
        currentTarget: StoragePluginLocation,
        storageLocation: StoragePluginLocation?
    ) -> (targetLocation: StoragePluginLocation, hasChanges: Bool) {
        let targetLocation = targetLocationAfterStorageUpdate(
            currentTarget: currentTarget,
            storageLocation: storageLocation
        )
        return (
            targetLocation,
            hasSelectionChanges(
                targetLocation: targetLocation,
                storageLocation: storageLocation
            )
        )
    }

    nonisolated static func hasSelectionChanges(
        targetLocation: StoragePluginLocation,
        storageLocation: StoragePluginLocation?
    ) -> Bool {
        storageLocation.map { targetLocation != $0 } ?? false
    }
}
