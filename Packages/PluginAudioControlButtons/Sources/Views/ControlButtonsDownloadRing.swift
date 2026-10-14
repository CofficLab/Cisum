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
    /// 圆环直径，等于播放按钮尺寸。
    let diameter: CGFloat

    /// 轨道与弧的粗细。
    ///
    /// 按直径的固定比例推导：按钮只有 32~72pt，固定值在两端都会失真。
    private var lineWidth: CGFloat {
        max(2, diameter * 0.06)
    }

    /// 中心百分比的字号。
    ///
    /// 必须由**直径**推导，不能挂在 `lineWidth` 上：描边是为了在小控件上保持
    /// 视觉克制才压到 2pt 的，若按它算字号会得到 3pt 的文字——macOS 上完全
    /// 不可读（这正是本视图初版的缺陷）。
    ///
    /// 下限 10pt 保证在任何按钮尺寸下都可辨认；上限 14pt 避免大按钮上数字
    /// 显得笨重。两者都落在直径的 26% 以内，不会挤到圆环内壁。
    private var fontSize: CGFloat {
        max(10, min(diameter * 0.26, 14))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                // 留出余量而非压到极限：缩得太小会退化成同样看不清的问题。
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .accessibilityIdentifier("cisum.player.button.download.progress")
        .accessibilityValue(Text("\(Int(progress * 100))%"))
    }
}

// MARK: - 预览

#Preview("Download Ring") {
    VStack(spacing: 24) {
        // 覆盖控制区按钮的实际尺寸区间（controlButtonMaximumSize = 72）。
        HStack(spacing: 24) {
            ForEach([32.0, 44.0, 56.0, 72.0], id: \.self) { size in
                ControlButtonsDownloadRing(progress: 0.42, diameter: size)
                    .frame(width: size, height: size)
            }
        }

        HStack(spacing: 24) {
            ForEach([32.0, 44.0, 56.0, 72.0], id: \.self) { size in
                ControlButtonsDownloadRing(progress: 1, diameter: size)
                    .frame(width: size, height: size)
            }
        }
    }
    .padding()
    .background(Color.orange)
}
