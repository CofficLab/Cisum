import MagicKit
import SwiftUI

/**
 * 用途：展示书籍仓库的状态提示信息
 * 属性说明：
 *   - variant: 提示类型（empty: 空状态, loading: 加载中）
 * 使用场景：在书籍列表为空或正在加载时显示友好的提示界面
 */
struct BookDBTips: View {
    enum Variant {
        case empty
        case loading
    }

    @EnvironmentObject var app: AppProvider
    var variant: Variant = .empty

    var supportedFormats: String {
        BookPlugin.supportedExtensions.joined(separator: ",")
    }

    var body: some View {
        VStack {
            switch variant {
            case .empty:
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.yellow)
                        Text(Config.isDesktop ? "将有声书文件夹拖到这里可添加" : "仓库为空", tableName: "Book-DBView")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    Text("支持的格式：\(supportedFormats)", tableName: "Book-DBView")
                        .font(.subheadline)
                        .foregroundStyle(.white)

                    #if os(macOS)
                        HStack { Text("或", tableName: "Book-DBView").foregroundStyle(.white) }
                        Button(
                            action: {
                                if let disk = BookPlugin.getBookDisk() {
                                    disk.openFolder()
                                }
                            },
                            label: {
                                Label { Text("打开仓库目录并放入文件", tableName: "Book-DBView") } icon: { Image(systemName: "doc.viewfinder.fill") }
                            }
                        )
                    #endif

                    if Config.isNotDesktop {
                        BtnAdd().buttonStyle(.bordered).foregroundStyle(.white)
                    }
                }
            case .loading:
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.yellow)
                        Text(Config.isDesktop ? "将有声书文件夹拖到这里可添加" : "有声书仓库为空", tableName: "Book-DBView")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text("正在读取仓库", tableName: "Book-DBView")
                        .font(.headline)
                        .foregroundStyle(.white)
                    VStack(spacing: 10) {
                        Text("支持的格式：\(supportedFormats)", tableName: "Book-DBView")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.top, 6)
                }
            }
        }
        .inCard()
        .shadow(radius: 8)
    }
}

// MARK: - Preview

#Preview("空状态") {
    BookDBTips(variant: .empty)
        .frame(width: 300, height: 300)
}

#Preview("加载中") {
    BookDBTips(variant: .loading)
        .frame(width: 300, height: 300)
}

#if os(macOS)
    #Preview("App - Large") {
        ContentView()
            .inRootView()
            .frame(width: 600, height: 1000)
    }

    #Preview("App - Small") {
        ContentView()
            .inRootView()
            .frame(width: 500, height: 800)
    }
#endif

#if os(iOS)
    #Preview("iPhone") {
        ContentView()
            .inRootView()
    }
#endif
