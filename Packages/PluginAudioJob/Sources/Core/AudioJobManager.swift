import Foundation
import MagicKit
import OSLog

public actor AudioJobManager: SuperLog {
    public nonisolated static let emoji = "📝"
    public static let shared = AudioJobManager()

    public nonisolated static let verbose = false

    private var jobs: [String: any AudioJob] = [:]
    private var runningJobs: [String: UUID] = [:]

    private init() {}

    public func register(_ job: any AudioJob) {
        if let existingJob = jobs[job.identifier],
           runningJobs[job.identifier] != nil {
            existingJob.cancel()
            runningJobs[job.identifier] = nil
        }

        jobs[job.identifier] = job

        if Self.verbose {
            os_log("📋 Audio job registered: \(job.identifier) - \(job.name)")
        }
    }

    public func unregister(_ identifier: String) {
        if runningJobs[identifier] != nil {
            jobs[identifier]?.cancel()
        }

        jobs.removeValue(forKey: identifier)
        runningJobs[identifier] = nil

        if Self.verbose {
            os_log("🗑️ Audio job unregistered: \(identifier)")
        }
    }

    public func startJob(_ identifier: String) {
        guard let job = jobs[identifier] else {
            os_log(.error, "❌ Audio job does not exist: \(identifier)")
            return
        }

        if runningJobs[identifier] != nil {
            if Self.verbose {
                os_log("⚠️ Audio job already running: \(identifier)")
            }
            return
        }

        let runID = UUID()
        runningJobs[identifier] = runID

        if Self.verbose {
            os_log("🚀 Audio job started: \(job.name)")
        }

        Task { [weak self] in
            do {
                try await job.execute()
            } catch is CancellationError {
                if Self.verbose {
                    os_log("⏹️ Audio job cancelled: \(identifier)")
                }
            } catch {
                os_log(.error, "❌ Audio job failed [\(identifier)]: \(error)")
            }

            await self?.markJobFinished(identifier, runID: runID)
        }
    }

    public func stopJob(_ identifier: String) {
        guard let job = jobs[identifier] else {
            os_log(.error, "❌ Audio job does not exist: \(identifier)")
            return
        }

        job.cancel()
        runningJobs[identifier] = nil

        if Self.verbose {
            os_log("⏹️ Audio job stopped: \(identifier)")
        }
    }

    public func stopAllJobs() {
        for identifier in runningJobs.keys {
            jobs[identifier]?.cancel()
        }
        runningJobs.removeAll()

        if Self.verbose {
            os_log("⏹️ All audio jobs stopped")
        }
    }

    public func getAllJobStatus() -> [JobStatus] {
        jobs.values.map { job in
            JobStatus(
                identifier: job.identifier,
                name: job.name,
                isRunning: runningJobs[job.identifier] != nil
            )
        }
    }

    public func getJobStatus(_ identifier: String) -> JobStatus? {
        guard let job = jobs[identifier] else {
            return nil
        }

        return JobStatus(
            identifier: identifier,
            name: job.name,
            isRunning: runningJobs[identifier] != nil
        )
    }

    private func markJobFinished(_ identifier: String, runID: UUID) {
        guard runningJobs[identifier] == runID else { return }
        runningJobs[identifier] = nil
    }
}
