import Foundation
import OSLog
import SwiftUI

/// 音频后台任务协议
///
/// 定义后台任务的基本接口，具体任务需要实现此协议。
protocol AudioJob {
    /// 任务唯一标识符
    nonisolated var identifier: String { get }

    /// 任务名称
    nonisolated var name: String { get }

    /// 任务描述
    nonisolated var description: String { get }

    /// 执行任务
    func execute() async throws

    /// 取消任务
    func cancel()
}

/// 任务状态
struct JobStatus {
    let identifier: String
    let name: String
    let isRunning: Bool
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
