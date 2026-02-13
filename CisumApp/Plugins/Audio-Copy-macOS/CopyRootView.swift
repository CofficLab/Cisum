#if os(macOS)
    import MagicAlert
    import MagicKit
    import OSLog
    import SwiftData
    import SwiftUI
    import UniformTypeIdentifiers

    struct CopyRootView<Content>: View, SuperEvent, SuperLog, SuperThread where Content: View {
        nonisolated static var emoji: String { "🚛" }
        nonisolated static var verbose: Bool { false }

        @State var error: Error? = nil

        private var content: Content

        // CopyWorkerView 的状态
        @State private var isDropping = false
        @State private var outOfLimit = false

        @EnvironmentObject var m: MagicMessageProvider

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
                        .if(showProTips)

                    AudioCopyTips(variant: .drop)
                        .if(isDropping)
                }
                .infinite()
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

            // 检查是否超出限制
            let isOutOfLimit = await CopyPlugin.isOutOfLimit()
            await MainActor.run {
                self.outOfLimit = isOutOfLimit
            }
            if isOutOfLimit {
                return false
            }

            guard let disk = await MainActor.run(body: { AudioPlugin.getAudioDisk() }) else {
                os_log(.error, "\(self.t)No Disk")
                await MainActor.run { alert_error("No Disk") }
                return false
            }

            // 从 CopyPlugin 获取 worker
            guard let worker = CopyPlugin.getWorker() else {
                os_log(.error, "\(self.t)Failed to get worker")
                return false
            }

            var tasks: [(bookmark: Data, filename: String)] = []
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    do {
                        let urlData: Data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                                if let error = error {
                                    continuation.resume(throwing: error)
                                } else if let data = data {
                                    continuation.resume(returning: data)
                                } else {
                                    continuation.resume(throwing: NSError(domain: "", code: -1))
                                }
                            }
                        }
                        if let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                            // Create a security-scoped bookmark
                            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                            tasks.append((bookmark: bookmarkData, filename: url.lastPathComponent))
                        }
                    } catch {
                        os_log(.error, "\(self.t)Failed to load URL or create bookmark: \(error.localizedDescription)")
                    }
                }
            }

            if Self.verbose {
                os_log("\(self.t)🎁 获取到 \(tasks.count) 个文件")
            }

            if tasks.isNotEmpty {
                await worker.append(tasks: tasks, folder: disk)
            }

            return true
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
                let isOutOfLimit = await CopyPlugin.isOutOfLimit()
                await MainActor.run {
                    self.outOfLimit = isOutOfLimit
                }
            }
        }
    }

    // MARK: - Preview

    #Preview("App") {
        ContentView()
            .inRootView()
            .withDebugBar()
    }
#endif
