import MagicKit
import SwiftUI

struct AudioDBTips: View {
    enum Variant {
        case empty
        case loading
        case sorting
    }

    @EnvironmentObject var app: AppProvider
    var variant: Variant = .empty

    var supportedFormats: String {
        AudioPlugin.supportedExtensions.joined(separator: ",")
    }

    var body: some View {
        VStack(spacing: 20) {
            switch variant {
            case .empty:
                HStack {
                    Image(systemName: "info.circle.fill").foregroundStyle(.blue)
                    Text(Config.isDesktop ? "将音乐文件拖到这里可添加" : "歌曲仓库为空")
                        .font(.title3)
                }
                Text("支持的格式：\(supportedFormats)")
                    .font(.subheadline)

                #if os(macOS)
                    if let disk = AudioPlugin.getAudioDisk() {
                        HStack { Text("或") }

                        Label { Text("打开仓库目录并放入文件") } icon: { Image(systemName: "doc.viewfinder.fill") }
                            .inCard(.regularMaterial)
                            .shadowSm()
                            .hoverScale(105)
                            .inButtonWithAction {
                                disk.openFolder()
                            }
                    }
                #endif

                BtnAdd().buttonStyle(.bordered).if(Config.isNotDesktop)

            case .loading:
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.yellow)
                    Text(Config.isDesktop ? "将音乐文件拖到这里可添加" : "歌曲仓库为空")
                        .font(.title3)
                }
                ProgressView()
                    .controlSize(.large)
                Text("正在读取仓库")
                    .font(.headline)
                VStack(spacing: 10) {
                    Text("支持的格式：\(supportedFormats)")
                        .font(.footnote)
                }
                .padding(.top, 6)

            case .sorting:
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.yellow)
                    Text(Config.isDesktop ? "将音乐文件拖到这里可添加" : "歌曲仓库为空")
                        .font(.title3)
                }
                ProgressView()
                    .controlSize(.large)
                Text("正在排序")
                    .font(.headline)
                VStack(spacing: 10) {
                    Text("支持的格式：\(supportedFormats)")
                        .font(.footnote)
                }
                .padding(.top, 6)
            }
        }
        .padding()
        .background(Config.rootBackground.opacity(0.8))
        .background(.background.opacity(0.5))
        .roundedMedium()
        .shadowXl()
    }
}

// MARK: - Preview

#Preview {
    Group {
        AudioDBTips(variant: .empty)
            .frame(width: 300, height: 200)

        AudioDBTips(variant: .loading)
            .frame(width: 300, height: 200)

        AudioDBTips(variant: .sorting)
            .frame(width: 300, height: 200)
    }
    .infinite()
    .inScrollView()
    .frame(height: 800)
    .frame(width: 500)
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
