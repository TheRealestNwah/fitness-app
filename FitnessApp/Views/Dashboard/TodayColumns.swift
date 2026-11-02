import SwiftUI

/// Lays the Today cards out in as many columns as fit the width (`TodayLayout.columnCount`),
/// giving each card, in order, to the shortest column so far (`TodayLayout.pack`). A wide Mac
/// window gets three balanced columns instead of two with the tall cards all on the left.
struct TodayColumns: Layout {
    var spacing: CGFloat = 16

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = width(for: proposal, subviews: subviews)
        let height = frames(width: width, subviews: subviews).map(\.maxY).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, frames(width: bounds.width, subviews: subviews)) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          proposal: ProposedViewSize(frame.size))
        }
    }

    /// The proposed width, or the widest card's own width when nothing is proposed.
    private func width(for proposal: ProposedViewSize, subviews: Subviews) -> CGFloat {
        if let width = proposal.width, width.isFinite { return width }
        return subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
    }

    private func frames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        let columns = TodayLayout.columnCount(fitting: width, spacing: spacing)
        let columnWidth = max((width - spacing * CGFloat(columns - 1)) / CGFloat(columns), 0)
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height }
        var bottoms = Array(repeating: CGFloat(0), count: columns)
        return zip(TodayLayout.pack(heights: heights, into: columns, spacing: spacing), heights).map { column, height in
            let y = bottoms[column] > 0 ? bottoms[column] + spacing : 0
            bottoms[column] = y + height
            return CGRect(x: CGFloat(column) * (columnWidth + spacing), y: y, width: columnWidth, height: height)
        }
    }
}
