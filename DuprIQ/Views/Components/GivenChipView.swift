import SwiftUI

/// One "given" in a code problem, drawn as a labelled chip.
///
/// Exam questions bury their conditions in a paragraph, and candidates lose
/// points by missing one. Pulling them out into a readable row is the whole
/// reason this exists: the reader should be able to see every condition at a
/// glance and notice which one the question is really about.
struct GivenChipView: View {
    let given: Given
    var scale: CGFloat = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 2 * scale) {
            Text(given.label.uppercased())
                .font(.system(size: 9 * scale, weight: .heavy))
                .kerning(0.6)
                .foregroundStyle(Theme.inkTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 3 * scale) {
                Text(given.value)
                    .font(.system(size: 15 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                if let unit = given.unit {
                    Text(unit)
                        .font(.system(size: 11 * scale, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .padding(.horizontal, 10 * scale)
        .padding(.vertical, 7 * scale)
        .background(
            RoundedRectangle(cornerRadius: 9 * scale)
                .fill(Theme.worksheet)
                .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9 * scale)
                .strokeBorder(Theme.worksheetEdge, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(given.spokenLabel)
    }
}

/// The row of conditions above a question.
///
/// Wraps rather than scrolls. A condition that has scrolled off the side is a
/// condition the reader will not account for, and on a derating problem that is
/// the difference between the right answer and a plausible wrong one.
struct GivensView: View {
    let givens: [Given]
    var scale: CGFloat = 1.0

    var body: some View {
        FlowLayout(spacing: 7 * scale) {
            ForEach(givens) { given in
                GivenChipView(given: given, scale: scale)
            }
        }
    }
}

/// A minimal wrapping layout. `LazyVGrid` cannot do this: the chips are
/// different widths and fixed columns would leave ragged gaps.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = layout(subviews: subviews, maxWidth: maxWidth)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        let rows = layout(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            // Centred: a left-aligned last row under a full one reads as broken.
            var x = bounds.minX + (bounds.width - row.width) / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layout(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let projected = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty, projected > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
