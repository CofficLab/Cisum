import SwiftUI

extension AvatarView {
    /// 加载中视图组件
    struct LoadingView: View {
        let shape: AvatarViewShape
        let size: CGSize
        let backgroundColor: Color

        init(
            shape: AvatarViewShape = .circle,
            size: CGSize,
            backgroundColor: Color = .blue.opacity(0.1)
        ) {
            self.shape = shape
            self.size = size
            self.backgroundColor = backgroundColor
        }

        var body: some View {
            ProgressView()
                .controlSize(.small)
                .frame(width: size.width, height: size.height)
                .background(backgroundColor)
                .clipShape(shape)
        }
    }
}

