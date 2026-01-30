import MagicKit
import OSLog
import SwiftUI

struct Guide: View, SuperLog {
    nonisolated static let emoji = "🧭"
    nonisolated static let verbose = false

    @EnvironmentObject var pluginProvider: PluginProvider
    @State var currentGuidePageIndex: Int = 0

    private var views: [AnyView] {
        pluginProvider.plugins.compactMap { $0.addGuideView() }
    }

    var body: some View {
        ZStack {
            // 显示当前页面
            if currentGuidePageIndex < views.count {
                pluginViewWithNavigation(at: currentGuidePageIndex)
            } else {
                GuideDoneView(isActive: true)
            }
        }
    }
}

// MARK: - View Builder

extension Guide {
    /// 生成带有导航按钮的插件视图
    /// - Parameter index: 视图索引
    /// - Returns: 包含导航按钮的插件视图
    @ViewBuilder
    private func pluginViewWithNavigation(at index: Int) -> some View {
        ZStack {
            views[index]

            // 为每个插件页面添加导航按钮
            VStack {
                Spacer()

                // 统一的导航按钮
                HStack(spacing: 16) {
                    // 上一页按钮
                    if index > 0 {
                        Image.previousPage
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(.regularMaterial, in: Circle())
                            .hoverScale(105)
                            .shadowSm()
                            .inButtonWithAction {
                                currentGuidePageIndex = index - 1
                            }
                    }

                    // 下一页按钮
                    Image.nextPage
                        .font(.title2)
                        .frame(width: 50, height: 50)
                        .background(.regularMaterial, in: Circle())
                        .hoverScale(105)
                        .shadowSm()
                        .inButtonWithAction {
                            currentGuidePageIndex = index + 1
                        }
                }
                .padding(.bottom, 16)
            }
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
