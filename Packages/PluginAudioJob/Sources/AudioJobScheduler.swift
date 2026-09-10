import Foundation
import MagicKit
import OSLog

public actor AudioJobScheduler: SuperLog {
    public nonisolated static let emoji = "⏰"
    public static let shared = AudioJobScheduler()

    public nonisolated static let verbose = false

    private var isSetup = false

    private init() {}

    public func setup() {
        guard !isSetup else { return }

        #if os(iOS)
            setupiOS()
        #elseif os(macOS)
            setupmacOS()
        #endif

        isSetup = true
    }

    #if os(iOS)
        private func setupiOS() {
            if Self.verbose {
                os_log("📱 Setting up iOS audio background jobs")
            }
        }
    #endif

    #if os(macOS)
        private func setupmacOS() {
            if Self.verbose {
                os_log("🖥️ Audio background jobs run directly on macOS")
            }
        }
    #endif

    public func executePendingJobs() async {
        if Self.verbose {
            os_log("🔄 Executing pending audio jobs")
        }

        let manager = AudioJobManager.shared
        let allJobs = await manager.getAllJobStatus()

        for job in allJobs {
            await manager.startJob(job.identifier)
        }
    }
}
