import Foundation

/// Coffic Lab 官方应用目录。
///
/// 目录是编译期固定的静态数据：产品列表变化频率极低（按月计），走网络请求
/// 反而会带来「设置页在离线时是空的」这种负体验。
public enum CofficApps {
    /// 全部应用（展示顺序即列表顺序）。
    public static let all: [CofficApp] = [
        CofficApp(
            id: "lumi",
            name: "Lumi",
            taglineKey: "An AI-powered personal desktop assistant for macOS",
            systemImage: "sparkles",
            urlString: "https://coffic.cn/lumi"
        ),
        CofficApp(
            id: "gitok",
            name: "GitOK",
            taglineKey: "Project management on macOS",
            // `git-branch` 不是有效的 SF Symbol（SwiftUI 会静默渲染空白），
            // 分支图标的正确名称是 `arrow.triangle.branch`。
            systemImage: "arrow.triangle.branch",
            urlString: "https://coffic.cn/gitok"
        ),
        CofficApp(
            id: "wakey",
            name: "Wakey",
            taglineKey: "Keep your Mac awake",
            systemImage: "cup.and.saucer.fill",
            urlString: "https://coffic.cn/wakey"
        ),
        CofficApp(
            id: "travelmode",
            name: "TravelMode",
            taglineKey: "Control your network on macOS",
            systemImage: "network",
            urlString: "https://coffic.cn/travelmode"
        ),
        CofficApp(
            id: "booklet-maker",
            name: "BookletMaker",
            taglineKey: "Turn a PDF into a fold-and-staple booklet",
            systemImage: "book.closed",
            urlString: "https://coffic.cn/booklet"
        )
    ]

    /// 「全部产品」入口。
    public static let allProductsURLString = "https://coffic.cn/products"
}
