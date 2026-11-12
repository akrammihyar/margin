import SwiftUI
import Observation
import MarginCore

/// One pen mark on the tab: one task of today.
enum TabMark: Equatable {
    case done, open, focus
}

@MainActor @Observable
final class TabState {
    var edge: ScreenEdge = .right
    /// One mark for each task of today, in list order.
    var marks: [TabMark] = []
    /// The focus task name, when it is shown on the tab.
    var text: String?
    var hovering = false
}

/// Sizes and colours of the edge tab. Change these values to change its look.
enum TabMetrics {
    /// The marks float this far from the screen edge. The window covers the space, so the
    /// pointer at the very edge of the screen still touches the tab.
    static let inset: CGFloat = 5
    /// The colour of completed marks and of the outline.
    static let orange = Color(red: 1.0, green: 0.54, blue: 0.12)

    // Pen marks
    static let markThickness: CGFloat = 3
    static let markGap: CGFloat = 4
    static let markLengths: [CGFloat] = [13, 10, 15, 11, 14, 9, 12]   // repeats; gives a hand-made look
    static let markTilt: Double = -8
    static let maxMarks = 16
    static let emptyLength: CGFloat = 36      // the single line of a day without tasks
    static let marksPadding: CGFloat = 6
    static let marksThickness: CGFloat = inset + 15 + 5

    // Focus name capsule
    static let pillCapsule: CGFloat = 24
    static let pillThickness: CGFloat = pillCapsule + inset
    static let maxCharacters = 24
    static let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
    static let groupGap: CGFloat = 6

    static func shortened(_ text: String) -> String {
        text.count > maxCharacters ? String(text.prefix(maxCharacters)).trimmingCharacters(in: .whitespaces) + "…" : text
    }

    static func pillLength(for text: String) -> CGFloat {
        ceil((shortened(text) as NSString).size(withAttributes: [.font: font]).width) + 28
    }

    static func marksLength(count: Int) -> CGFloat {
        let n = min(count, maxMarks)
        let body = n == 0 ? emptyLength : CGFloat(n) * markThickness + CGFloat(n - 1) * markGap
        return body + 2 * marksPadding
    }

    /// The size of the tab along the edge and away from it.
    static func size(marks: Int, text: String?) -> (length: CGFloat, thickness: CGFloat) {
        guard let text else { return (marksLength(count: marks), marksThickness) }
        return (marksLength(count: marks) + groupGap + pillLength(for: text), pillThickness)
    }
}

/// The tab near the screen edge: short pen marks, like notes in the margin of a page.
/// One mark for each task of today. Orange = completed, grey = open, long = the focus task.
/// The view is static when idle: it changes only when the tasks change or on hover.
struct EdgeTabView: View {
    let state: TabState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var vertical: Bool { state.edge.isVertical }

    /// The side of the window that touches the screen edge.
    private var edgeSide: Edge.Set {
        switch state.edge {
        case .left: return .leading
        case .right: return .trailing
        case .top: return .top
        case .bottom: return .bottom
        }
    }

    private var edgeAlignment: Alignment {
        switch state.edge {
        case .left: return .leading
        case .right: return .trailing
        case .top: return .top
        case .bottom: return .bottom
        }
    }

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: TabMetrics.groupGap)) : AnyLayout(HStackLayout(spacing: TabMetrics.groupGap))
        layout {
            marks
            if let text = state.text { namePill(text) }
        }
        .padding(edgeSide, TabMetrics.inset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edgeAlignment)
        .animation(reduceMotion ? nil : .spring(duration: 0.25), value: state.hovering)
        .animation(reduceMotion ? nil : .spring(duration: 0.3), value: state.marks)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }

    private var label: String {
        let done = state.marks.filter { $0 == .done }.count
        let summary = state.marks.isEmpty ? "No tasks today" : "\(done) of \(state.marks.count) tasks completed"
        return "Margin. \(summary)" + (state.text.map { ". Focus task: \($0)" } ?? "")
    }

    // MARK: Marks

    private var marks: some View {
        let shown = Array(state.marks.prefix(TabMetrics.maxMarks))
        let layout = vertical
            ? AnyLayout(VStackLayout(alignment: state.edge == .right ? .trailing : .leading, spacing: TabMetrics.markGap))
            : AnyLayout(HStackLayout(alignment: state.edge == .top ? .top : .bottom, spacing: TabMetrics.markGap))
        return layout {
            if shown.isEmpty {
                stroke(length: TabMetrics.emptyLength, color: TabMetrics.orange, along: true)
            } else {
                ForEach(Array(shown.enumerated()), id: \.offset) { index, mark in
                    stroke(length: length(index, mark), color: color(mark), along: false)
                        .rotationEffect(.degrees(state.hovering ? 0 : TabMetrics.markTilt))
                }
            }
        }
        .padding(TabMetrics.marksPadding)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(TabMetrics.orange.opacity(state.hovering ? 0.22 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(TabMetrics.orange.opacity(state.hovering ? 1 : 0), lineWidth: 1.2)
        )
        // A soft dark edge keeps the marks visible on light and on dark backgrounds.
        .shadow(color: .black.opacity(scheme == .dark ? 0.6 : 0.25), radius: 1.2, y: 0.5)
    }

    /// One pen mark. `along` true draws it along the edge (the line of an empty day).
    private func stroke(length: CGFloat, color: Color, along: Bool) -> some View {
        let acrossEdge = vertical != along
        return Capsule()
            .fill(color)
            .frame(width: acrossEdge ? length : TabMetrics.markThickness,
                   height: acrossEdge ? TabMetrics.markThickness : length)
    }

    private func length(_ index: Int, _ mark: TabMark) -> CGFloat {
        mark == .focus ? 15 : TabMetrics.markLengths[index % TabMetrics.markLengths.count]
    }

    private func color(_ mark: TabMark) -> Color {
        switch mark {
        case .done: return TabMetrics.orange
        case .focus: return scheme == .dark ? .white : .black
        case .open: return (scheme == .dark ? Color.white : Color.black).opacity(0.5)
        }
    }

    // MARK: Focus name

    private func namePill(_ text: String) -> some View {
        let length = TabMetrics.pillLength(for: text)
        return Text(TabMetrics.shortened(text))
            .font(Font(TabMetrics.font))
            .foregroundStyle(scheme == .dark ? Color(red: 1.0, green: 0.72, blue: 0.42) : Color(red: 0.72, green: 0.33, blue: 0.0))
            .lineLimit(1)
            .fixedSize()
            .rotationEffect(.degrees(state.edge == .left ? -90 : (state.edge == .right ? 90 : 0)))
            .frame(width: vertical ? TabMetrics.pillCapsule : length, height: vertical ? length : TabMetrics.pillCapsule)
            .background(Capsule(style: .continuous).fill(scheme == .dark ? Color.black.opacity(0.55) : Color.white.opacity(0.7)))
            .overlay(Capsule(style: .continuous).strokeBorder(TabMetrics.orange, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
}
