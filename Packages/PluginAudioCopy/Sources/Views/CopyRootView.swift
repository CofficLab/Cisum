import MagicKit
#if os(macOS)
    import CisumUIComponents
import LumiUI
    import MagicKit
    import OSLog
    import ProviderAudioLibrary
    import ProviderToast
    import SwiftData
    import SwiftUI
    import UniformTypeIdentifiers

    enum AudioCopyLimitPolicy {
        static func allowedTaskCount(
            currentAudioCount: Int,
            pendingCopyTaskCount: Int = 0,
            requestedTaskCount: Int,
            maxAudioCount: Int,
            isFreeVersion: Bool
        ) -> Int {
            guard isFreeVersion else { return requestedTaskCount }

            let occupiedCount = currentAudioCount + pendingCopyTaskCount
            let remainingCount = max(0, maxAudioCount - occupiedCount)
            return min(requestedTaskCount, remainingCount)
        }
    }

    struct CopyRootView<Content>: View, SuperEvent, SuperLog, SuperThread where Content: View {
        nonisolated static var emoji: String { "🚛" }
        nonisolated static var verbose: Bool { false }

        @State var error: Error? = nil
        @Environment(\.toastProviding) private var toastProvider

        private var content: Content

        // CopyWorkerView 的状态
        @State private var isDropping = false
        @State private var outOfLimit = false

        init(@ViewBuilder content: () -> Content) {
            if Self.verbose {
                os_log("\(Self.i)")
            }

            self.content = content()
        }

        private var showProTips: Bool {
            outOfLimit && isDropping
        }

        var body: some View {
            ZStack {
                content
                VStack {
                    AudioCopyTips(variant: .pro)
                        .cisumIf(showProTips)

                    AudioCopyTips(variant: .drop)
                        .cisumIf(isDropping)
                }
                .cisumInfinite()
                .onAppear(perform: onAppear)
                .onDrop(of: [UTType.fileURL], isTargeted: self.$isDropping, perform: onDropProviders)
            }
        }
    }

    // MARK: - Action

    extension CopyRootView {
        @MainActor
        private func handleDrop(_ providers: [NSItemProvider]) async {
            let result = await onDrop(providers)
            if !result {
                os_log(.error, "\(self.t)Drop operation failed")
            }
        }

        private func onDropProviders(_ providers: [NSItemProvider]) -> Bool {
            Task {
                await handleDrop(providers)
            }
            return true
        }

        func onDrop(_ providers: [NSItemProvider]) async -> Bool {
            if Self.verbose {
                os_log("\(self.t)🚀 开始处理拖放文件")
            }

            let droppedFiles = await Self.droppedFileURLs(from: providers)
            var sourceURLs = Self.uniqueSupportedAudioSources(droppedFiles.urls)
            var preparationErrors = droppedFiles.errors

            if Self.verbose {
                os_log("\(self.t)🎁 获取到 \(sourceURLs.count) 个文件")
            }

            if Self.shouldReportPartialDroppedURLLoadFailure(sourceURLs: sourceURLs, errors: preparationErrors) {
                await MainActor.run {
                    toastProvider?.warning(String(localized: "Some dropped files could not be loaded", bundle: .module))
                }
            }

            guard Self.shouldPrepareCopyInfrastructure(sourceCount: sourceURLs.count) else {
                if Self.shouldReportPreparationFailure(preparedCount: sourceURLs.count, preparationErrors: preparationErrors),
                   let error = preparationErrors.first {
                    await MainActor.run {
                        toastProvider?.error(String(localized: "Failed to prepare file: \(error.localizedDescription)", bundle: .module))
                    }
                }
                if Self.shouldShowNoFilesAdded(taskCount: 0, preparationErrors: preparationErrors) {
                    await MainActor.run {
                        toastProvider?.error(String(localized: "No files were added", bundle: .module))
                    }
                }
                return false
            }

            if Self.shouldReportSkippedUnsupportedSources(droppedFiles.urls, sourceURLs: sourceURLs) {
                await MainActor.run {
                    toastProvider?.warning(String(localized: "Some files were skipped because they are not supported audio files", bundle: .module))
                }
            }

            let allowedTaskCount = await AudioCopyService.allowedTaskCount(requestedTaskCount: sourceURLs.count)
            if allowedTaskCount < sourceURLs.count {
                if allowedTaskCount == 0 {
                    await MainActor.run {
                        toastProvider?.error(String(localized: "Copy limit reached", bundle: .module))
                    }
                    return false
                }

                sourceURLs = Array(sourceURLs.prefix(allowedTaskCount))
                await MainActor.run {
                    toastProvider?.warning(String(localized: "Only \(allowedTaskCount) files were added because the free copy limit is almost full", bundle: .module))
                }
            }

            // 检查是否超出限制
            let isOutOfLimit = await AudioCopyService.isOutOfLimit()
            await MainActor.run {
                self.outOfLimit = isOutOfLimit
            }
            if isOutOfLimit {
                await MainActor.run {
                    toastProvider?.error(String(localized: "Copy limit reached", bundle: .module))
                }
                return false
            }

            guard let disk = await MainActor.run(body: { AudioCopyService.getAudioDisk() }) else {
                os_log(.error, "\(self.t)No Disk")
                await MainActor.run {
                    toastProvider?.error(String(localized: "Storage location is unavailable", bundle: .module))
                }
                return false
            }

            // 从 AudioCopyService 获取 worker
            guard let worker = AudioCopyService.getWorker() else {
                os_log(.error, "\(self.t)Failed to get worker")
                await MainActor.run {
                    toastProvider?.error(String(localized: "Copy service is unavailable", bundle: .module))
                }
                return false
            }

            var tasks: [(bookmark: Data, filename: String)] = []
            for url in sourceURLs {
                do {
                    let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    tasks.append((bookmark: bookmarkData, filename: url.lastPathComponent))
                } catch {
                    preparationErrors.append(error)
                    os_log(.error, "\(self.t)Failed to create bookmark: \(error.localizedDescription)")
                }
            }

            if tasks.isNotEmpty {
                await worker.append(tasks: tasks, folder: disk)
            } else {
                if Self.shouldReportPreparationFailure(preparedCount: tasks.count, preparationErrors: preparationErrors),
                   let error = preparationErrors.first {
                    await MainActor.run {
                        toastProvider?.error(String(localized: "Failed to prepare file: \(error.localizedDescription)", bundle: .module))
                    }
                }
                if Self.shouldShowNoFilesAdded(taskCount: tasks.count, preparationErrors: preparationErrors) {
                    await MainActor.run {
                        toastProvider?.error(String(localized: "No files were added", bundle: .module))
                    }
                }
                return false
            }

            return true
        }

        nonisolated static func isSupportedAudioFile(_ url: URL) -> Bool {
            guard !url.isFolder else { return false }
            return AudioPluginInfo.supportedExtensions.contains(url.pathExtension.lowercased())
        }

        nonisolated static func uniqueSupportedAudioSources(_ urls: [URL]) -> [URL] {
            var seenIdentities = Set<String>()
            var uniqueURLs: [URL] = []
            uniqueURLs.reserveCapacity(urls.count)

            for url in urls where isSupportedAudioFile(url) {
                let identity = canonicalCopySourceIdentity(for: url)
                guard seenIdentities.insert(identity).inserted else {
                    continue
                }

                uniqueURLs.append(url)
            }

            return uniqueURLs
        }

        nonisolated static func shouldReportSkippedUnsupportedSources(_ urls: [URL], sourceURLs: [URL]) -> Bool {
            urls.count > sourceURLs.count && !sourceURLs.isEmpty
        }

        nonisolated static func shouldReportPartialDroppedURLLoadFailure(sourceURLs: [URL], errors: [Error]) -> Bool {
            !sourceURLs.isEmpty && !errors.isEmpty
        }

        static func droppedFileURL(from provider: NSItemProvider) async throws -> URL? {
            var fileURLDataError: Error?

            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                do {
                    let data: Data? = try await withCheckedThrowingContinuation { continuation in
                        provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                            if let error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: data)
                            }
                        }
                    }

                    if let data, let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL {
                        return url
                    }
                } catch {
                    fileURLDataError = error
                }
            }

            if let url = try await droppedURLObject(from: provider) {
                return url
            }

            if let fileURLDataError {
                throw fileURLDataError
            }

            return nil
        }

        private static func droppedURLObject(from provider: NSItemProvider) async throws -> URL? {
            guard provider.canLoadObject(ofClass: URL.self) else { return nil }

            return try await withCheckedThrowingContinuation { continuation in
                _ = provider.loadObject(ofClass: URL.self) { object, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: object)
                    }
                }
            }
        }

        static func droppedFileURLs(from providers: [NSItemProvider]) async -> (urls: [URL], errors: [Error]) {
            var urls: [URL] = []
            var errors: [Error] = []

            for provider in providers {
                do {
                    if let url = try await droppedFileURL(from: provider) {
                        urls.append(url)
                    }
                } catch {
                    errors.append(error)
                }
            }

            return (urls, errors)
        }

        nonisolated static func representsSameCopySource(_ lhs: URL, _ rhs: URL) -> Bool {
            canonicalCopySourceIdentity(for: lhs) == canonicalCopySourceIdentity(for: rhs)
        }

        nonisolated static func canonicalCopySourceIdentity(for url: URL) -> String {
            guard url.isFileURL else {
                return url.standardized.absoluteString
            }

            guard FileManager.default.fileExists(atPath: url.path) else {
                return url.standardizedFileURL.path
            }

            return url.resolvingSymlinksInPath().standardizedFileURL.path
        }

        nonisolated static func shouldShowNoFilesAdded(taskCount: Int, preparationErrors: [Error]) -> Bool {
            taskCount == 0 && preparationErrors.isEmpty
        }

        nonisolated static func shouldReportPreparationFailure(preparedCount: Int, preparationErrors: [Error]) -> Bool {
            preparedCount == 0 && !preparationErrors.isEmpty
        }

        nonisolated static func shouldPrepareCopyInfrastructure(sourceCount: Int) -> Bool {
            sourceCount > 0
        }
    }

    // MARK: - Event Handler

    extension CopyRootView {
        func onAppear() {
            if Self.verbose {
                os_log("\(self.t)🖥️ onAppear")
            }
            // 检查是否超出限制
            Task {
                let isOutOfLimit = await AudioCopyService.isOutOfLimit()
                await MainActor.run {
                    self.outOfLimit = isOutOfLimit
                }
            }
        }
    }
#endif
