import MagicAlert
import MagicKit
import OSLog
import SwiftData
import SwiftUI

/// Demo mode 下的音频列表视图
/// 显示固定的模拟音频文件列表，所有数据都是模拟的
struct AudioListDemo: View, SuperLog {
    nonisolated static let emoji = "🎭"
    nonisolated static let verbose = false

    @EnvironmentObject var playManController: PlayMan
    @Environment(\.demoMode) var isDemoMode

    /// 模拟音频文件列表
    private static let demoAudioFiles: [String] = [
        "清风徐来.mp3",
        "夜空中最亮的星.m4a",
        "成都.flac",
        "理想.wav",
        "南山南.mp3",
        "董小姐.m4a",
        "安和桥.flac",
        "斑马斑马.wav",
        "平凡之路.mp3",
        "童话镇.m4a",
        "追光者.flac",
        "消愁.wav",
        "演员.mp3",
        "体面.m4a",
        "说散就散.flac",
        "往后余生.wav",
        "像我这样的人.mp3",
        "起风了.m4a",
        "少年.flac",
        "岁月神偷.wav",
    ]

    /// 获取 demo mode 下的模拟 URL 列表
    private static func getDemoURLs() -> [URL] {
        // 创建一个虚拟的存储目录 URL
        let baseURL = URL(fileURLWithPath: "/demo/audio")
        return demoAudioFiles.map { baseURL.appendingPathComponent($0) }
    }

    /// 模拟的音频文件 URL 列表
    private let urls: [URL] = Self.getDemoURLs()

    /// 音频总数
    private var totalCount: Int {
        urls.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("共 \(totalCount.description)")
                Spacer()

                if Config.isNotDesktop {
                    BtnAdd()
                        .font(.title2)
                        .labelStyle(.iconOnly)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // 音频列表
            VStack(spacing: 0) {
                ForEach(urls, id: \.self) { url in
                    AudioItemDemo(url)
                }
            }
        }
        .if(self.isDemoMode)
    }
}

// MARK: Preview

#Preview("Demo Audio List") {
    AudioListDemo()
        .inRootView()
        .inDemoMode()
        .inMagicContainer()
}

#Preview("App Store Album Art") {
    AppStoreAlbumArt()
        .inMagicContainer(.macBook13, scale: 1)
}
