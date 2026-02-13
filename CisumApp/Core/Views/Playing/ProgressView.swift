import MagicKit
import SwiftUI

struct PlayingProgressView: View {
    @Environment(\.demoMode) var isDemoMode
    @Environment(\.downloadingMode) var isDownloadingMode
    @EnvironmentObject var playMan: PlayMan

    var body: some View {
        if isDownloadingMode {
            downloadingProgressView
        } else if isDemoMode {
            demoProgressView
        } else {
            playMan.makeProgressView()
        }
    }

    // MARK: 下载中场景的进度条

    private var downloadingProgressView: some View {
        VStack(alignment: .center, spacing: 8) {
            // 进度条（禁用状态，位于起点）
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景条
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))

                    // 进度（起点，即进度为0）
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 0)
                }
            }
            .frame(height: 4)
            .shadow3xl()

            // 时间标签（显示为未知）
            HStack {
                Text("--:--", tableName: "Core")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.5))

                Spacer()

                Text("--:--", tableName: "Core")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 演示模式的进度条

    private var demoProgressView: some View {
        VStack(alignment: .center, spacing: 8) {
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景条
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))

                    // 进度
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * 0.35)
                }
            }
            .frame(height: 4)
            .shadow3xl()

            // 时间标签
            HStack {
                Text("1:24", tableName: "Core")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()

                Text("3:45", tableName: "Core")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
