import MagicDevice
import MagicKit
import OSLog
import SwiftData
import SwiftUI

struct ControlView: View, SuperLog {
    static let verbose = false

    @Environment(\.demoMode) var isDemoMode
    @EnvironmentObject var appManager: AppProvider
    @EnvironmentObject var message: StateProvider
    @EnvironmentObject var playMan: PlayMan
    @EnvironmentObject var p: PluginProvider

    @State var showHeroView = true
    @State var showBtnsView = true
    @State var showOperationView = false

    // MARK: 子视图是否展示

    var showDB: Bool { appManager.showDB }
    var showStateMessage: Bool { message.stateMessage.count > 0 }
    var showSliderView: Bool { true }

    var body: some View {
        if Self.verbose {
            os_log("\(self.t)开始渲染")
        }
        return GeometryReader { geo in
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    // MARK: 封面图和标题

                    if showHeroView {
                        HeroView()
                            .infinite()
                    }

                    // MARK: 状态

                    StateView()
                        .frame(height: getStateHeight(geo))
                        .frame(maxWidth: .infinity)

                    // MARK: 操作栏

                    if showOperationView {
                        OperationView(geo: geo)
                            .frame(height: getOperationHeight(geo))
                    }

                    // MARK: 进度栏

                    if showSliderView {
                        PlayingProgressView()
                            .padding()
                    }

                    // MARK: 控制栏

                    if showBtnsView {
                        ControlBtns()
                            .frame(height: getButtonsHeight(geo))
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, getBottomHeight(geo))
                    }
                }

                // MARK: 横向的封面图

                if shouldShowRightAlbum(geo) {
                    // 最大宽度=控制栏的高度+系统标题栏高度
                    HStack {
                        Spacer(minLength: 0)
                        playMan.makeHeroView()
                    }
                    .frame(maxWidth: geo.size.height * 1.3)
                    .onAppear {
                        appManager.rightAlbumVisible = true
                    }
                    .onDisappear {
                        appManager.rightAlbumVisible = false
                    }
                }
            }
            .padding(.bottom, 0)
            .padding(.horizontal, 0)
            .frame(maxHeight: .infinity)
        }
        .ignoresSafeArea(edges: Config.isDesktop ? .horizontal : .all)
        .frame(minHeight: Config.controlViewMinHeight)
    }

    // MARK: 状态栏的高度

    private func getStateHeight(_ geo: GeometryProxy) -> CGFloat {
        if geo.size.height <= Config.minHeight {
            return 24
        }

        if geo.size.height <= Config.minWidth + 100 {
            return 36
        }

        return 48
    }

    // MARK: 操作栏的高度

    private func getOperationHeight(_ geo: GeometryProxy) -> CGFloat {
        if showOperationView == false {
            return 0
        }

        return getButtonsHeight(geo) * 0.6
    }

    // MARK: 控制按钮的高度

    private func getButtonsHeight(_ geo: GeometryProxy) -> CGFloat {
        min(geo.size.width / 5, 900, geo.size.height / 4)
    }

    // MARK: 底部Padding的高度

    private func getBottomHeight(_ geo: GeometryProxy) -> CGFloat {
        if Config.hasHomeIndicator() && Config.isNotDesktop && showDB == false {
            return 10
        }

        return 0
    }

    // MARK: 是否显示右侧的封面图

    private func shouldShowRightAlbum(_ geo: GeometryProxy) -> Bool {
        geo.size.width > MagicDevice.iPad_mini.width
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
