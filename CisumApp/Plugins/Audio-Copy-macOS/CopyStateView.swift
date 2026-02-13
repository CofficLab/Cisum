#if os(macOS)
import MagicKit
import MagicAlert
import OSLog
import SwiftData
import SwiftUI

struct CopyStateView: View, SuperLog, SuperThread {
    @EnvironmentObject var app: AppProvider
    @EnvironmentObject var messageManager: StateProvider

    @State private var showCopying = false
    @State private var taskCount: Int = 0

    nonisolated static let emoji = "🖥️"
    nonisolated static var verbose: Bool { false }

    /// 是否应该显示状态视图
    private var shouldShow: Bool {
        taskCount > 0
    }

    var body: some View {
        Group {
            if shouldShow {
                HStack {
                    Image(systemName: "info.circle")
                    Text("正在复制 \(taskCount) 个文件", tableName: "Audio-Copy-macOS")
                    Image.list.inButtonWithAction {
                        self.showCopying.toggle()
                    }
                }
                .font(.callout)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(MagicBackground.deepForest)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentTransition(.numericText(value: Double(taskCount)))
                .popover(isPresented: $showCopying) {
                    CopyList()
                }
                .transition(.opacity.combined(with: .scale))
                .shadowSm()
            }
        }
        .onCopyTaskCountChanged(perform: handleCopyTaskCountChanged)
        .onCopyTaskFinished(perform: handleCopyTaskFinished)
    }
}

// MARK: - View

extension CopyStateView {
    func makeInfoView(_ i: String) -> some View {
        HStack {
            Image(systemName: "info.circle")
                .foregroundStyle(.white)
            Text(i)
                .foregroundStyle(.white)
        }
        .inCard()
        .font(.title3)
    }
}

// MARK: - Event Handler

extension CopyStateView {
    func handleCopyTaskCountChanged(_ count: Int) {
        taskCount = count
    }

    func handleCopyTaskFinished(_ lastCount: Int) {
        // 任务完成，清零任务数量
        taskCount = 0
        alert_info("复制完成")
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
#endif
