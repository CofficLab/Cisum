import LumiUI
import SwiftUI

/// 播放按钮上的下载进度环。
///
/// 造型与音乐库列表项的下载进度环（`PluginAudioDBView.AudioDownloadProgressRing`）
/// 保持一致：底层浅色轨道 + 上层圆头进度弧 + 中心百分比。两者刻意不共享代码
/// ——前者由 `CloudDownloadProgressStore` 驱动（多个文件、各自独立进度），
/// 本视图由当前播放的单一 `PlaybackStatus` 驱动，数据源与生命周期都不同，
/// 共用一个类型只会把两边的差异塞进参数里。
///
/// 之所以不复用封面区已有的 `cisum.player.download.overlay` 大圆环：那个圆环
/// 受布局条件约束（控制区高度 > 450pt 才渲染），默认小窗口下不出现，而下载
/// 反馈恰恰在这种窗口最需要。按钮是常驻控件，不受布局门槛影响。
struct ControlButtonsDownloadRing: View {
    /// 进度（0...1）；调用方保证已夹取到合法区间。
    let progress: Double
    /// 轨道与弧的粗细，按钮尺寸较小时需比列表项更细。
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // 百分比字号按按钮尺寸缩放，避免在小尺寸下溢出圆环。
            Text("\(Int(progress * 100))%")
                .font(.system(size: lineWidth * 1.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .accessibilityIdentifier("cisum.player.button.download.progress")
        .accessibilityValue(Text("\(Int(progress * 100))%"))
    }
}

// MARK: - 预览

#Preview("Download Ring") {
    HStack(spacing: 20) {
        ControlButtonsDownloadRing(progress: 0.42, lineWidth: 2)
            .frame(width: 32, height: 32)
            .background(Color.orange)

        ControlButtonsDownloadRing(progress: 0.08, lineWidth: 3)
            .frame(width: 40, height: 40)
            .background(Color.orange)
    }
    .padding()
}