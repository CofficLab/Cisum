import SwiftUI

/// Cisum 品牌标记：胶片卷盘。
///
/// 与 AppIcon 的造型一致（象牙白卷盘 + 金色压边 + 深棕盘面 + 五个绿色片孔
/// + 从右侧探出的一小段片头），但用矢量形状重绘，因此可以跟随主题着色、
/// 参与动画，且在任意尺寸下都保持清晰。
///
/// 之所以不用 AppIcon 的 PNG：启动阶段资源目录未必已就绪，且位图无法参与
/// 呼吸/扫光动画——加载页恰恰需要这两者。
///
/// ## 画布与卷盘的关系
///
/// 片头要从卷盘**右侧边缘之外**探出，因此它必须画在卷盘之下（被压住的
/// 部分正是「从盘里伸出来」的观感），并且整体画布要比卷盘宽：
/// 若画布宽度等于卷盘直径，溢出的片头会被画布裁掉。
struct CisumBrandMark: View {
    /// 卷盘直径。
    let size: CGFloat

    /// 盘面配色。可注入以适配不同背景亮度。
    var scheme: ColorScheme

    /// 卷盘外壳（象牙白）。
    private var reelShell: Color {
        scheme == .dark ? Color(white: 0.97) : Color(white: 0.99)
    }

    /// 盘面（深棕）。
    private var reelFace: Color {
        Color(red: 0.29, green: 0.17, blue: 0.09)
    }

    /// 压边金环。
    private var reelRim: Color {
        Color(red: 0.82, green: 0.60, blue: 0.18)
    }

    /// 片孔与片头（品牌绿）。
    private var reelHole: Color {
        Color(red: 0.13, green: 0.52, blue: 0.33)
    }

    /// 画布宽度：卷盘直径 + 片头探出的部分。
    private var canvasWidth: CGFloat { size * 1.22 }

    /// 画布高度。
    private var canvasHeight: CGFloat { size }

    /// 卷盘在画布中的中心（整体左移，给右侧片头让位）。
    private var reelCenterX: CGFloat { -size * 0.08 }

    init(size: CGFloat = 96, scheme: ColorScheme = .light) {
        self.size = size
        self.scheme = scheme
    }

    var body: some View {
        ZStack {
            // 片头：画在卷盘之下，从卷盘右侧探出的一个小圆凸起。
            // 尺寸与偏移按「卷盘边缘 + 探出量」推算，保证有一部分真的露在外面；
            // 画成圆形（而非方条）才与 AppIcon 的造型一致。
            Circle()
                .fill(reelHole)
                .frame(width: size * 0.17, height: size * 0.17)
                .offset(x: reelCenterX + size * 0.54, y: size * 0.02)

            // 卷盘外壳：象牙白圆盘，形成边缘高光。
            Circle()
                .fill(reelShell)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(scheme == .dark ? 0.42 : 0.22), radius: size * 0.07, y: size * 0.03)

            // 盘面：深棕圆盘，带一圈金色压边。
            Circle()
                .fill(reelFace)
                .overlay(
                    Circle()
                        .stroke(reelRim, lineWidth: max(1, size * 0.03))
                )
                .frame(width: size * 0.66, height: size * 0.66)

            // 片孔：四片大孔呈十字排列，中心一片小孔。
            ForEach(Self.holeLayout.indices, id: \.self) { index in
                let hole = Self.holeLayout[index]
                Circle()
                    .fill(reelHole)
                    .frame(width: size * hole.diameter, height: size * hole.diameter)
                    .offset(x: reelCenterX + size * hole.x, y: size * hole.y)
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
    }

    /// 五个片孔的相对布局（尺寸以卷盘直径 `size` 为单位）。
    private static let holeLayout: [(diameter: CGFloat, x: CGFloat, y: CGFloat)] = [
        (0.145, 0.0, -0.13),    // 上
        (0.145, 0.0, 0.13),     // 下
        (0.145, -0.13, 0.0),    // 左
        (0.145, 0.13, 0.0),     // 右
        (0.078, 0.0, 0.0)       // 中心
    ]
}

#Preview("Light") {
    CisumBrandMark(size: 120, scheme: .light)
        .padding(40)
        .background(Color(white: 0.95))
}

#Preview("Dark") {
    CisumBrandMark(size: 120, scheme: .dark)
        .padding(40)
        .background(Color(white: 0.12))
}
