import Foundation
import MagicKit
import OSLog
import SwiftUI

/// Demo mode 下的音频列表项视图组件
/// 用于在 AudioListDemo 中展示单个模拟音频文件
struct AudioItemDemo: View, Equatable, SuperLog {
    nonisolated static let emoji = "🎭"
    nonisolated static let verbose = false

    let url: URL

    /// 可用的系统图标列表（音乐相关）
    public static let iconNames: [String] = [
        "music.note",
        "music.note.list",
        "music.quarternote.3",
        "music.mic",
        "waveform",
        "waveform.circle",
        "speaker.wave.2",
        "headphones",
    ]

    /// 根据 URL 获取随机但稳定的图标名称
    private var iconName: String {
        let index = abs(url.hashValue) % Self.iconNames.count
        return Self.iconNames[index]
    }

    /// 根据 URL 获取随机但稳定的颜色
    private var iconColor: Color {
        let colors: [Color] = [
            .blue,
            .purple,
            .pink,
            .orange,
            .green,
            .teal,
            .cyan,
            .indigo,
        ]
        let index = abs(url.hashValue) % colors.count
        return colors[index]
    }

    /// 模拟的文件大小（demo mode 下使用固定值）
    private var sizeText: String {
        // 根据文件扩展名返回不同的模拟大小
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp3":
            return "4.2 MB"
        case "m4a":
            return "3.8 MB"
        case "flac":
            return "25.6 MB"
        case "wav":
            return "12.4 MB"
        default:
            return "5.0 MB"
        }
    }

    nonisolated static func == (lhs: AudioItemDemo, rhs: AudioItemDemo) -> Bool {
        lhs.url == rhs.url
    }

    init(_ url: URL) {
        self.url = url
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 头像部分 - 使用系统图标和圆形背景
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 40, height: 40)

            // 文件信息部分
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Text(sizeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: Preview

#Preview("Audio Item Demo") {
    VStack {
        AudioItemDemo(URL(fileURLWithPath: "/demo/audio/清风徐来.mp3"))
        AudioItemDemo(URL(fileURLWithPath: "/demo/audio/夜空中最亮的星.m4a"))
        AudioItemDemo(URL(fileURLWithPath: "/demo/audio/成都.flac"))
    }
    .padding()
    .inMagicContainer()
}

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

#Preview("Icon Names Preview") {
    VStack(spacing: 20) {
        Text("图标预览")
            .font(.title)
            .bold()

        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 16) {
            ForEach(AudioItemDemo.iconNames, id: \.self) { iconName in
                VStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                        )

                    Text(iconName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 80)
                }
            }
        }
        .padding()
    }
    .inMagicContainer()
}

