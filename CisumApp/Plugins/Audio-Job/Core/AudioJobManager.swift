import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 音频后台任务管理器
///
/// 负责管理和调度所有音频相关的后台任务。
actor AudioJobManager: SuperLog {
    static let shared = AudioJobManager()

    nonisolated static let verbose = false

    /// 所有注册的任务
    private var jobs: [String: any AudioJob] = [:]

    /// 当前运行中的任务
    private var runningJobs: Set<String> = []

    private init() {
        if Self.verbose {
            os_log("\(self.t)🎬 任务管理器已初始化")
        }
    }

    /// 注册任务
    func register(_ job: any AudioJob) {
        jobs[job.identifier] = job

        if Self.verbose {
            os_log("\(self.t)📋 注册: \(job.identifier) - \(job.name)")
        }
    }

    /// 取消注册任务
    func unregister(_ identifier: String) {
        jobs.removeValue(forKey: identifier)
        runningJobs.remove(identifier)

        if Self.verbose {
            os_log("\(self.t)🗑️ 取消注册: \(identifier)")
        }
    }

    /// 启动任务
    func startJob(_ identifier: String) {
        guard let job = jobs[identifier] else {
            os_log(.error, "\(self.t)❌ 任务不存在: \(identifier)")
            return
        }

        if runningJobs.contains(identifier) {
            if Self.verbose {
                os_log("\(self.t)⚠️ 任务运行中: \(identifier)")
            }
            return
        }

        runningJobs.insert(identifier)

        if Self.verbose {
            os_log("\(self.t)🚀 启动: \(job.name)")
        }

        Task {
            do {
                try await job.execute()
            } catch is CancellationError {
                if Self.verbose {
                    os_log("\(self.t)⏹️ 已取消: \(identifier)")
                }
            } catch {
                os_log(.error, "\(self.t)❌ 失败 [\(identifier)]: \(error)")
            }

            // 从运行队列中移除
            runningJobs.remove(identifier)
        }
    }

    /// 停止任务
    func stopJob(_ identifier: String) {
        guard let job = jobs[identifier] else {
            os_log(.error, "\(self.t)❌ 任务不存在: \(identifier)")
            return
        }

        job.cancel()
        runningJobs.remove(identifier)

        if Self.verbose {
            os_log("\(self.t)⏹️ 停止: \(identifier)")
        }
    }

    /// 停止所有任务
    func stopAllJobs() {
        for identifier in runningJobs {
            jobs[identifier]?.cancel()
        }
        runningJobs.removeAll()

        if Self.verbose {
            os_log("\(self.t)⏹️ 停止所有任务")
        }
    }

    /// 获取所有任务状态
    func getAllJobStatus() -> [JobStatus] {
        jobs.values.map { job in
            JobStatus(
                identifier: job.identifier,
                name: job.name,
                isRunning: runningJobs.contains(job.identifier)
            )
        }
    }

    /// 获取指定任务状态
    func getJobStatus(_ identifier: String) -> JobStatus? {
        guard let job = jobs[identifier] else {
            return nil
        }

        return JobStatus(
            identifier: identifier,
            name: job.name,
            isRunning: runningJobs.contains(identifier)
        )
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
