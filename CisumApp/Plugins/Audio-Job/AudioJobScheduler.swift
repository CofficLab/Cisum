import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 跨平台后台任务调度器
///
/// 负责在不同平台上调度后台任务。目前支持基本的任务执行。
actor AudioJobScheduler: SuperLog {
    static let shared = AudioJobScheduler()

    nonisolated static let verbose = true

    private var isSetup = false

    private init() {
        if Self.verbose {
            os_log("\(self.t)🎬 调度器已初始化")
        }
    }

    /// 设置调度器
    func setup() {
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
                os_log("\(self.t)📱 设置 iOS 后台任务")
            }

            // TODO: 注册 BGTaskScheduler
            // 后续可以根据需要添加 iOS 特定的后台任务处理
        }
    #endif

    #if os(macOS)
        private func setupmacOS() {
            if Self.verbose {
                os_log("\(self.t)🖥️ macOS 平台，后台任务直接执行")
            }
            // macOS 不需要特殊设置
        }
    #endif

    /// 执行所有挂起的任务
    func executePendingJobs() async {
        if Self.verbose {
            os_log("\(self.t)🔄 执行挂起的任务")
        }

        let manager = AudioJobManager.shared
        let allJobs = await manager.getAllJobStatus()

        for job in allJobs {
            await manager.startJob(job.identifier)
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
