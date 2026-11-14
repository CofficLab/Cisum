import SwiftUI

extension AvatarView {
    /// 下载进度视图组件
    struct DownloadingView: View {
        let progress: Double
        let shape: AvatarViewShape
        let size: CGSize
        let backgroundColor: Color

        init(
            progress: Double,
            shape: AvatarViewShape = .circle,
            size: CGSize,
            backgroundColor: Color = .blue.opacity(0.1)
        ) {
            self.progress = progress
            self.shape = shape
            self.size = size
            self.backgroundColor = backgroundColor
        }
        
        var padding: CGFloat {
            return self.size.width * 0.1
        }

        var body: some View {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(
                        lineWidth: 4,
                        lineCap: .round
                    ))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(padding)
            .frame(width: size.width, height: size.height)
            .background(backgroundColor)
            .clipShape(shape)
            // 下载进度覆盖层标识：列表行用它断言「iCloud 文件正在下载」。
            // 挂在 AvatarView 本体上无效（自定义视图不把修饰符透传给内容），
            // 只能加在真正渲染出来的子视图上。
            .accessibilityIdentifier("cisum.avatar.download.progress")
            .accessibilityValue(Text("\(Int(progress * 100))%"))
        }
    }
}

