import SwiftUI
import Observation
import MarginCore

@MainActor @Observable
final class TabState {
    var edge: ScreenEdge = .right
    /// The focus task name, when it is shown on the tab.
    var text: String?
    /// A focus task exists but its name is hidden.
    var showDot = false
    var hovering = false
}

enum TabMetrics {
    /// The capsule floats this far from the screen edge. The window covers the space, so the
    /// pointer at the very edge of the screen still touches the tab.
    static let inset: CGFloat = 5
    static let thinCapsule: CGFloat = 10
    static let pillCapsule: CGFloat = 24
    static let thinThickness: CGFloat = thinCapsule + inset
    static let pillThickness: CGFloat = pillCapsule + inset
    static let thinLength: CGFloat = 64
    static let maxCharacters = 24
    static let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
    /// The colour of the tab outline.
    static let orange = Color(red: 1.0, green: 0.54, blue: 0.12)

    static func shortened(_ text: String) -> String {
        text.count > maxCharacters ? String(text.prefix(maxCharacters)).trimmingCharacters(in: .whitespaces) + "…" : text
    }

    static func length(for text: String?) -> CGFloat {
        guard let text else { return thinLength }
        let width = (shortened(text) as NSString).size(withAttributes: [.font: font]).width
        return ceil(width) + 28
    }
}

/// The tab near the screen edge: a floating capsule with an orange outline.
/// Thin when there is no focus task; wider, with the task name, when there is.
struct EdgeTabView: View {
    let state: TabState
    @Environment(\.colorScheme) private var scheme

    private var fill: Color {
        if state.hovering { return TabMetrics.orange.opacity(0.35) }
        return scheme == .dark ? Color.black.opacity(0.55) : Color.white.opacity(0.7)
    }

    private var textColor: Color {
        scheme == .dark ? Color(red: 1.0, green: 0.72, blue: 0.42) : Color(red: 0.72, green: 0.33, blue: 0.0)
    }

    /// The side of the window that touches the screen edge.
    private var edgeSide: Edge.Set {
        switch state.edge {
        case .left: return .leading
        case .right: return .trailing
        case .top: return .top
        case .bottom: return .bottom
        }
    }

    var body: some View {
        ZStack {
            if let text = state.text {
                Text(TabMetrics.shortened(text))
                    .font(Font(TabMetrics.font))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(state.edge == .left ? -90 : (state.edge == .right ? 90 : 0)))
            } else if state.showDot {
                Circle().fill(TabMetrics.orange).frame(width: 4, height: 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Capsule(style: .continuous).fill(fill))
        .overlay(Capsule(style: .continuous).strokeBorder(TabMetrics.orange, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        .padding(edgeSide, TabMetrics.inset)
        .animation(.easeOut(duration: 0.12), value: state.hovering)
        .accessibilityElement()
        .accessibilityLabel(state.text.map { "Margin. Focus task: \($0)" } ?? "Margin task list")
        .accessibilityAddTraits(.isButton)
    }
}
