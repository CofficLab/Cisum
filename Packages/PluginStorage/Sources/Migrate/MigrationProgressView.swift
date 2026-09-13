import CisumUIComponents

import OSLog
import SwiftUI

enum MigrationProgressUpdatePolicy {
    static func shouldApplyUpdate(currentGeneration: Int, updateGeneration: Int) -> Bool {
        currentGeneration == updateGeneration
    }

    static func normalizedProgress(_ progress: Double) -> Double {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }
}

enum MigrationProgressErrorMessagePolicy {
    static func alertMessage(errorMessage: String?, migrationCancelled: Bool) -> String {
        let details = errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDetails = details?.isEmpty == false ? details! : "Unknown error"
        let partialMigrationNote = migrationCancelled ? "\n\nSome files may already have been migrated to the new location." : ""

        return """
        \(resolvedDetails)

        The storage location has been reset to the original location. No setting changes were saved.\(partialMigrationNote)

        Recommended next steps:
        1. Check permissions and available space for both storage locations.
        2. Review the data in both storage locations if any files were moved.
        3. Retry the migration after resolving the issue.
        """
    }
}

struct MigrationProgressView: View {
    @LumiTheme private var appTheme
    @StateObject private var migrationManager = MigrationManager()
    let sourceLocation: StoragePluginLocation?
    let targetLocation: StoragePluginLocation
    let sourceURL: URL?
    let targetURL: URL?
    let onDismiss: () -> Void
    let dependencies: StorageDependencies

    @State private var processedFiles: [FileStatus] = []
    @State private var sourceFiles: [String] = []
    @State private var targetFiles: [String] = []
    @State private var errorMessage: String?
    @State private var migrationProgress = 0.0
    @State private var currentMigratingFile = ""
    @State private var completionMessage = ""
    @State private var showConfirmation = true // 用于显示确认对话框
    @State private var migrationCompleted = false // 添加新状态变量
    @State private var migrationCancelled = false // 添加新状态来跟踪取消状态
    @State private var cancellationRequested = false
    @State private var showCancelConfirmation = false
    @State private var migrationGeneration = 0

    // 添加 errorAlertMessage 计算属性
    var errorAlertMessage: String {
        Self.errorAlertMessage(errorMessage: errorMessage, migrationCancelled: migrationCancelled)
    }

    nonisolated static func errorAlertMessage(errorMessage: String?, migrationCancelled: Bool) -> String {
        MigrationProgressErrorMessagePolicy.alertMessage(
            errorMessage: errorMessage,
            migrationCancelled: migrationCancelled
        )
    }

    nonisolated static func completionMessage(shouldMigrate: Bool) -> String {
        localizedCompletionMessage(for: completionMessageKey(shouldMigrate: shouldMigrate))
    }

    nonisolated static func completionMessageKey(shouldMigrate: Bool) -> String {
        shouldMigrate ? "Migration completed" : "Switched to new location"
    }

    private nonisolated static func localizedCompletionMessage(for key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module)
    }

    nonisolated static var migrationWarningTitleKey: String { "Important:" }
    nonisolated static var migrationWarningICloudKey: String {
        "• If source data is in iCloud and has files that are not downloaded, migration may take longer while downloads finish"
    }
    nonisolated static var migrationWarningDoNotCloseKey: String {
        "• Do not close the app during migration. Cancelling may leave data incomplete"
    }
    nonisolated static var migrationWarningMigrateKey: String {
        "• Migrate Data: Move existing data to the new location"
    }
    nonisolated static var migrationWarningUseDirectlyKey: String {
        "• Use Directly: Use the new location and keep existing data unchanged"
    }
    nonisolated static var migrationWarningCancelKey: String {
        "• Cancel: Keep the original location unchanged"
    }

    private nonisolated static func localizedStorageText(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module)
    }

    nonisolated static func shouldPerformMigration(sourceURL: URL?, targetURL: URL?, requestedMigration: Bool) -> Bool {
        requestedMigration && sourceURL != nil && targetURL != nil
    }

    nonisolated static func canMigrateExistingData(sourceLocation: StoragePluginLocation?, sourceURL: URL?) -> Bool {
        guard sourceLocation != nil, let sourceURL else { return false }
        return FileManager.default.fileExists(atPath: sourceURL.path)
    }

    nonisolated static func shouldDisableInteractiveDismiss(
        showConfirmation: Bool,
        migrationCompleted: Bool,
        migrationCancelled: Bool,
        errorMessage: String?
    ) -> Bool {
        !showConfirmation && !migrationCompleted && !migrationCancelled && errorMessage == nil
    }

    nonisolated static func migrationRoots(
        sourceURL: URL?,
        targetURL: URL?,
        requestedMigration: Bool
    ) throws -> (source: URL, target: URL)? {
        guard let targetURL else {
            throw MigrationError.targetDirectoryNotFound
        }

        guard requestedMigration else { return nil }
        guard let sourceURL else {
            throw MigrationError.sourceDirectoryNotFound
        }

        return (sourceURL, targetURL)
    }

    nonisolated static func migratableSourceFileNames(
        in sourceURL: URL,
        contentsOfDirectory: (String) throws -> [String] = FileManager.default.contentsOfDirectory(atPath:)
    ) throws -> [String] {
        try contentsOfDirectory(sourceURL.path)
            .filter { $0 != ".DS_Store" }
            .sorted()
    }

    private func prepareForRetry() {
        migrationGeneration += 1
        migrationManager.resetCancellation()
        processedFiles.removeAll()
        sourceFiles.removeAll()
        targetFiles.removeAll()
        errorMessage = nil
        migrationProgress = 0.0
        currentMigratingFile = ""
        completionMessage = ""
        migrationCompleted = false
        migrationCancelled = false
        cancellationRequested = false
        loadSourceFiles()
        loadTargetFiles()
    }

    var body: some View {
        VStack(spacing: 5) {
            GroupBox {
                RepositoryInfoView(
                    isDesktop: dependencies.isDesktop,
                    title: String(localized: "Source Library", bundle: .module),
                    location: sourceLocation,
                    url: sourceURL
                ).frame(height: 200)
            }

            HStack {
                Spacer()
                Image(systemName: "arrow.down")
                    .foregroundColor(.secondary)
                    .imageScale(.large)
                    .font(.system(size: 12))
                Spacer()
            }

            GroupBox {
                RepositoryInfoView(
                    isDesktop: dependencies.isDesktop,
                    title: String(localized: "Target Library", bundle: .module),
                    location: targetLocation,
                    url: targetURL
                ).frame(height: 200)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Self.localizedStorageText(Self.migrationWarningTitleKey))
                        .font(.subheadline)
                        .foregroundColor(.orange)

                    Group {
                        Text(Self.localizedStorageText(Self.migrationWarningICloudKey))
                        Text(Self.localizedStorageText(Self.migrationWarningDoNotCloseKey))
                        Text(Self.localizedStorageText(Self.migrationWarningMigrateKey))
                        Text(Self.localizedStorageText(Self.migrationWarningUseDirectlyKey)).foregroundStyle(.primary)
                        Text(Self.localizedStorageText(Self.migrationWarningCancelKey))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }.frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)

            if !showConfirmation {
                migrationStatusView
            }

            if showConfirmation {
                confirmationButtons
            } else {
                actionButtons
            }
        }
        .padding()
        .onAppear {
            loadSourceFiles()
            loadTargetFiles()
        }
        .interactiveDismissDisabled(Self.shouldDisableInteractiveDismiss(
            showConfirmation: showConfirmation,
            migrationCompleted: migrationCompleted,
            migrationCancelled: migrationCancelled,
            errorMessage: errorMessage
        ))
    }

    private func startMigration(shouldMigrate: Bool) async {
        migrationGeneration += 1
        let generation = migrationGeneration

        do {
            let migrationRoots = try Self.migrationRoots(
                sourceURL: sourceURL,
                targetURL: targetURL,
                requestedMigration: shouldMigrate
            )

            if let migrationRoots {
                let manager = migrationManager
                manager.resetCancellation()

                try await Task.detached(priority: .userInitiated) {
                    try manager.migrate(
                        from: migrationRoots.source,
                        to: migrationRoots.target,
                        progressCallback: { progress, file in
                            Task { @MainActor in
                                guard Self.shouldApplyMigrationUpdate(
                                    currentGeneration: self.migrationGeneration,
                                    updateGeneration: generation
                                ) else { return }
                                self.migrationProgress = Self.normalizedMigrationProgress(progress)
                                self.currentMigratingFile = file
                                self.updateFileStatus(file)
                            }
                        },
                        downloadProgressCallback: { file, downloadStatus in
                            Task { @MainActor in
                                guard Self.shouldApplyMigrationUpdate(
                                    currentGeneration: self.migrationGeneration,
                                    updateGeneration: generation
                                ) else { return }
                                self.updateFileDownloadStatus(file, downloadStatus: downloadStatus)
                            }
                        },
                        verbose: true
                    )
                }.value
            } else {
                // 如果选择直接使用，立即将进度设置为 100%
                await MainActor.run {
                    self.migrationProgress = 1.0
                }
            }

            // 更新存储位置
            await MainActor.run {
                guard Self.shouldApplyMigrationUpdate(
                    currentGeneration: self.migrationGeneration,
                    updateGeneration: generation
                ) else { return }
                let completionMessage = Self.completionMessage(shouldMigrate: migrationRoots != nil)
                dependencies.updateStorageLocation(targetLocation)
                self.migrationCompleted = true
                self.completionMessage = completionMessage
                self.currentMigratingFile = completionMessage
            }
        } catch MigrationError.migrationCancelled {
            await MainActor.run {
                guard Self.shouldApplyMigrationUpdate(
                    currentGeneration: self.migrationGeneration,
                    updateGeneration: generation
                ) else { return }
                self.cancellationRequested = false
                self.migrationCancelled = true
                self.currentMigratingFile = String(localized: "Migration Cancelled", bundle: .module)
            }
        } catch {
            await MainActor.run {
                guard Self.shouldApplyMigrationUpdate(
                    currentGeneration: self.migrationGeneration,
                    updateGeneration: generation
                ) else { return }
                self.cancellationRequested = false
                self.errorMessage = error.localizedDescription
                self.updateFileStatus(self.currentMigratingFile, error: error.localizedDescription)
            }
        }
    }

    nonisolated static func shouldApplyMigrationUpdate(currentGeneration: Int, updateGeneration: Int) -> Bool {
        MigrationProgressUpdatePolicy.shouldApplyUpdate(
            currentGeneration: currentGeneration,
            updateGeneration: updateGeneration
        )
    }

    nonisolated static func normalizedMigrationProgress(_ progress: Double) -> Double {
        MigrationProgressUpdatePolicy.normalizedProgress(progress)
    }

    nonisolated static func processedFilesAfterStatusUpdate(
        _ processedFiles: [FileStatus],
        fileName: String,
        sourceURL: URL?,
        error: String? = nil,
        fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)
    ) -> [FileStatus] {
        guard let index = processedFiles.firstIndex(where: { $0.name == fileName }) else {
            return processedFiles
        }

        var updatedFiles = processedFiles
        let currentFile = processedFiles[index]

        if let error {
            updatedFiles[index] = FileStatus(
                name: fileName,
                status: .failed(error),
                downloadStatus: currentFile.downloadStatus
            )
            return updatedFiles
        }

        let sourceFileExists = sourceURL.map {
            fileExists($0.appendingPathComponent(fileName).path)
        } ?? false

        updatedFiles[index] = FileStatus(
            name: fileName,
            status: sourceFileExists ? .processing : .completed,
            downloadStatus: sourceFileExists ? currentFile.downloadStatus : .local
        )
        return updatedFiles
    }

    nonisolated static func processedFilesAfterDownloadStatusUpdate(
        _ processedFiles: [FileStatus],
        fileName: String,
        downloadStatus: FileStatus.DownloadStatus
    ) -> [FileStatus] {
        guard let index = processedFiles.firstIndex(where: { $0.name == fileName }) else {
            return processedFiles
        }

        var updatedFiles = processedFiles
        let currentFile = processedFiles[index]
        updatedFiles[index] = FileStatus(
            name: fileName,
            status: currentFile.status,
            downloadStatus: downloadStatus
        )
        return updatedFiles
    }

    private func loadSourceFiles() {
        guard let sourceURL = sourceURL else { return }

        do {
            sourceFiles = try Self.migratableSourceFileNames(in: sourceURL)

            // 初始化所有文件为待处理状态
            processedFiles = sourceFiles.map { fileName in
                FileStatus(
                    name: fileName,
                    status: .pending,
                    downloadStatus: .local // 初始状态默认为本地文件
                )
            }
        } catch {
            os_log(.error, "Error loading source files: \(error.localizedDescription)")
        }
    }

    private func loadTargetFiles() {
        guard let targetURL = targetURL else { return }

        do {
            let fileManager = FileManager.default
            targetFiles = try fileManager.contentsOfDirectory(atPath: targetURL.path)
                .sorted()
        } catch {
            os_log(.error, "Error loading target files: \(error.localizedDescription)")
        }
    }

    private func updateFileStatus(_ fileName: String, error: String? = nil) {
        processedFiles = Self.processedFilesAfterStatusUpdate(
            processedFiles,
            fileName: fileName,
            sourceURL: sourceURL,
            error: error
        )

        if let error {
            errorMessage = error
        }
    }

    // 添加新方法来更新文件的下载状态
    private func updateFileDownloadStatus(_ fileName: String, downloadStatus: FileStatus.DownloadStatus) {
        processedFiles = Self.processedFilesAfterDownloadStatusUpdate(
            processedFiles,
            fileName: fileName,
            downloadStatus: downloadStatus
        )
    }

    private var confirmationButtons: some View {
        HStack(spacing: 48) {
            Button {
                onDismiss()
            } label: {
                Text("Cancel", bundle: .module)
            }
            .buttonStyle(.bordered)
            .help(String(localized: "Keep the original location unchanged", bundle: .module))

            Button {
                showConfirmation = false
                
                Task {
                    await startMigration(shouldMigrate: false)
                }
            } label: {
                Text("Use Directly", bundle: .module)
            }
            .buttonStyle(.borderedProminent)
            .help(String(localized: "Use the new location directly and keep existing data unchanged", bundle: .module))

            if Self.canMigrateExistingData(sourceLocation: sourceLocation, sourceURL: sourceURL) {
                Button {
                    showConfirmation = false

                    Task {
                        await startMigration(shouldMigrate: true)
                    }
                } label: {
                    Text("Migrate Data", bundle: .module)
                }
                .buttonStyle(.bordered)
                .help(String(localized: "Move existing data to the new location", bundle: .module))
            }
        }
        .padding()
        .frame(maxWidth: 500)
    }

    private var actionButtons: some View {
        Group {
            if errorMessage == nil {
                if migrationCompleted || migrationCancelled {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Done", bundle: .module)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        showCancelConfirmation = true
                    } label: {
                        Text(cancellationRequested ? "Cancelling..." : "Cancel Migration", bundle: .module)
                    }
                    .buttonStyle(.borderless)
                    .disabled(cancellationRequested)
                    .alert(Text("Cancel migration?", bundle: .module), isPresented: $showCancelConfirmation) {
                        Button(role: .cancel) { } label: {
                            Text("Continue Migration", bundle: .module)
                        }
                        Button(role: .destructive) {
                            cancellationRequested = true
                            migrationManager.cancelMigration()
                        } label: {
                            Text("Confirm Cancel", bundle: .module)
                        }
                    } message: {
                        Text("Cancelling migration may leave data incomplete. Waiting for migration to finish is recommended.", bundle: .module)
                    }
                }
            } else {
                HStack(spacing: 16) {
                    Button {
                        prepareForRetry()
                        showConfirmation = true
                    } label: {
                        Text("Retry", bundle: .module)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        onDismiss()
                    } label: {
                        Text("Give Up", bundle: .module)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.bottom)
    }

    // 修改状态显示部分
    private var migrationStatusView: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Migration Status", bundle: .module)
                    .font(.headline)
                    .foregroundColor(.primary)

                if migrationCompleted {
                    Text(completionMessage.isEmpty ? Self.completionMessage(shouldMigrate: true) : completionMessage)
                        .font(.subheadline)
                        .foregroundColor(appTheme.success)
                } else if migrationCancelled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Migration Cancelled", bundle: .module)
                            .font(.subheadline)
                            .foregroundColor(appTheme.warning)

                        Button {
                            prepareForRetry()
                            showConfirmation = true
                        } label: {
                            Text("Retry Migration", bundle: .module)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if let errorMessage = errorMessage {
                    Text("Migration failed: \(errorMessage)", bundle: .module)
                        .font(.subheadline)
                        .foregroundColor(appTheme.error)
                } else {
                    Text(cancellationRequested ? "Cancelling..." : "Migrating...", bundle: .module)
                        .font(.subheadline)
                        .foregroundColor(appTheme.info)
                }

                if !migrationCancelled {
                    ProgressView(value: migrationProgress)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}
