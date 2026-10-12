import MagicKit
#if os(macOS)
import CisumUIComponents
import LumiUI
import OSLog
import SwiftData
import SwiftUI

struct CopyList: View, SuperLog, SuperThread {
    nonisolated static let emoji = "📬"

    @ObservedObject private var viewModel: CopyViewModel

    init(viewModel: CopyViewModel, verbose: Bool = false) {
        self.viewModel = viewModel
        if verbose {
            os_log("\(Self.i)")
        }
    }

    var body: some View {
        Group {
            if !viewModel.tasks.isEmpty {
                taskList
            } else {
                emptyView
            }
        }
        .onAppear {
            viewModel.refreshTasks(postCountChanged: true)
        }
        .background(.regularMaterial)
        .cisumShadowSm()
    }

    /// 空视图
    private var emptyView: some View {
        AppEmptyState(
            icon: "tray",
            title: String(localized: "No copy tasks", bundle: .module)
        )
        .frame(minHeight: 160)
    }

    private var taskList: some View {
        List(selection: $viewModel.selection) {
            Section {
                ForEach(viewModel.tasks) { task in
                    AppListRow(isSelected: viewModel.selection == task.id) {
                        VStack(alignment: .leading) {
                            Text(task.originalFilename)
                                .lineLimit(1)
                            Text(task.message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(task.id)
                }
                .onDelete(perform: viewModel.deleteTasks)
            } header: {
                listHeader
            }
        }
        .frame(minWidth: 400)
    }

    private var listHeader: some View {
        let pendingCount = viewModel.tasks.filter { $0.error.isEmpty }.count
        let failedCount = viewModel.tasks.filter { !$0.error.isEmpty }.count

        return HStack {
            Text(CopyStatePresentation.message(pendingCount: pendingCount, failedCount: failedCount))
            Spacer()
        }
    }

    static func tasksToDelete(from offsets: IndexSet, in tasks: [CopyTask]) -> [CopyTask]? {
        var tasksToDelete: [CopyTask] = []
        tasksToDelete.reserveCapacity(offsets.count)

        for offset in offsets {
            guard tasks.indices.contains(offset) else {
                return nil
            }
            tasksToDelete.append(tasks[offset])
        }

        return tasksToDelete
    }
}
#endif
