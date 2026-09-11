import SwiftUI

/// 播放控制区右侧专辑视图；状态来自 PlaybackHeroViewModel，
/// 不依赖环境对象或具体播放引擎。
struct PlaybackHeroRightAlbumView: View {
    @ObservedObject private var viewModel: PlaybackHeroViewModel

    init(viewModel: PlaybackHeroViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        viewModel.makeMediaView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipped()
    }
}
