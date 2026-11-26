import SwiftUI

/// 按行换行的流式布局，用于宽度不一的标签。
struct VideoWrapLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let available = proposal.width ?? 1_000
        let rows = arrange(subviews: subviews, width: max(available, 1))
        let height = rows.reduce(0) { $0 + $1.height }
            + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: proposal.width ?? (rows.map(\.width).max() ?? 0), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews: subviews, width: max(bounds.width, 1)) {
            var x = bounds.minX
            for subview in row.subviews {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var subviews: [LayoutSubview] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let index = rows.count - 1
            let overflow = !rows[index].subviews.isEmpty && rows[index].width + spacing + size.width > width
            if overflow {
                rows.append(Row())
            }
            let target = rows.count - 1
            rows[target].width += (rows[target].subviews.isEmpty ? 0 : spacing) + size.width
            rows[target].height = max(rows[target].height, size.height)
            rows[target].subviews.append(subview)
        }
        return rows
    }
}
