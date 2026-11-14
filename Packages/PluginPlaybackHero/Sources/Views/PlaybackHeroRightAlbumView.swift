import SwiftUI

/// 播放控制区右侧专辑视图；状态来自 PlaybackHeroViewModel，
/// 不依赖环境对象或具体播放引擎。
struct PlaybackHeroRightAlbumView: View {
    @ObservedObject private var viewModel: PlaybackHeroViewModel

    init(viewModel: PlaybackHeroViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            if viewModel.isHeroVisible {
                viewModel.makeMediaView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
            } else if viewModel.showsIdlePlaceholder {
                // 宽窗口下右侧专辑栏是主封面位；没有当前曲目时用品牌占位图，
                // 否则右栏整片空白，与左栏的占位文案自相矛盾。
                Image.coffeeReelIcon(useDefaultBackground: true, handleRotation: 0)
                    .shadowXxxl()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
            }
        }
    }
}
