#if os(macOS)
import CisumUIComponents
import OSLog
import SwiftData
import SwiftUI

enum CopyStatePresentation {
    static func detailsButtonLabel(isShowing: Bool) -> String {
        String(
            localized: isShowing ? "Hide copy details" : "Show copy details",
            bundle: .module
        )
    }

    static func message(pendingCount: Int, failedCount: Int) -> String {
        if pendingCount > 0, failedCount > 0 {
            return String(
                localized: "Copying \(pendingCount) \(fileLabel(for: pendingCount)), \(failedCount) failed",
                bundle: .module
            )
        }

        if pendingCount > 0 {
            return String(
                localized: "Copying \(pendingCount) \(fileLabel(for: pendingCount))",
                bundle: .module
            )
        }

        if failedCount > 0 {
            return String(
                localized: "\(failedCount) \(taskLabel(for: failedCount)) failed",
                bundle: .module
            )
        }

        return ""
    }

    private static func fileLabel(for count: Int) -> String {
        count == 1 ? String(localized: "file", bundle: .module) : String(localized: "files", bundle: .module)
    }

    private static func taskLabel(for count: Int) -> String {
        count == 1 ? String(localized: "copy task", bundle: .module) : String(localized: "copy tasks", bundle: .module)
    }
}

struct CopyStateView: View, SuperLog, SuperThread {
    @LumiTheme private var appTheme
    @ObservedObject private var viewModel: CopyViewModel

    nonisolated static let emoji = "🖥️"
    nonisolated static var verbose: Bool { false }

    init(viewModel: CopyViewModel) {
        self.viewModel = viewModel
    }

    /// 是否应该显示状态视图
    private var shouldShow: Bool {
        viewModel.shouldShow
    }

    var body: some View {
        Group {
            if shouldShow {
                HStack {
                    Image(systemName: "info.circle")
                    Text(CopyStatePresentation.message(pendingCount: viewModel.pendingCount, failedCount: viewModel.failedCount))
                    Image.cisumList.cisumButton {
                        viewModel.showCopying.toggle()
                    }
                    .accessibilityLabel(CopyStatePresentation.detailsButtonLabel(isShowing: viewModel.showCopying))
                    .help(CopyStatePresentation.detailsButtonLabel(isShowing: viewModel.showCopying))
                }
                .accessibilityIdentifier("cisum.copy.state")
                .font(.callout)
                .foregroundStyle(appTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(appTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentTransition(.numericText(value: Double(viewModel.taskCount)))
                .popover(isPresented: $viewModel.showCopying) {
                    CopyList(viewModel: viewModel)
                }
                .transition(.opacity.combined(with: .scale))
                .cisumShadowSm()
            }
        }
        .onAppear(perform: viewModel.handleAppear)
    }
}
#endif
