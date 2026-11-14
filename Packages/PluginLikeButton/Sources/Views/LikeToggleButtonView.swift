import SwiftUI

public struct LikeToggleButtonView: View {
    public static var order: Int { 21 }
    @ObservedObject private var viewModel: LikeButtonViewModel

    init(viewModel: LikeButtonViewModel) { self.viewModel = viewModel }

    public var body: some View {
        if viewModel.hasAsset {
            Button {
                viewModel.toggleLike()
            } label: {
                Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(viewModel.isLiked ? .red : .primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.isLiked ? "Unlike" : "Like")
        }
    }
}
