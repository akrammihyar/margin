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
    static let thinThickness: CGFloat = 8
    static let thinLength: CGFloat = 64
    static let pillThickness: CGFloat = 24
    static let maxCharacters = 24
    static let font = NSFont.systemFont(ofSize: 11, weight: .medium)

    static func shortened(_ text: String) -> String {
        text.count > maxCharacters ? String(text.prefix(maxCharacters)).trimmingCharacters(in: .whitespaces) + "…" : text
    }

    static func length(for text: String?) -> CGFloat {
        guard let text else { return thinLength }
        let width = (shortened(text) as NSString).size(withAttributes: [.font: font]).width
        return ceil(width) + 28
    }
}

/// The tab on the screen edge. Thin when there is no focus task; a pill with the task name when there is.
struct EdgeTabView: View {
    let state: TabState

    private var shape: UnevenRoundedRectangle {
        let r: CGFloat = state.text == nil ? 5 : 11
        switch state.edge {
        case .right: return UnevenRoundedRectangle(topLeadingRadius: r, bottomLeadingRadius: r, bottomTrailingRadius: 0, topTrailingRadius: 0, style: .continuous)
        case .left: return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: r, topTrailingRadius: r, style: .continuous)
        case .top: return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: r, bottomTrailingRadius: r, topTrailingRadius: 0, style: .continuous)
        case .bottom: return UnevenRoundedRectangle(topLeadingRadius: r, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: r, style: .continuous)
        }
    }

    var body: some View {
        ZStack {
            if let text = state.text {
                Text(TabMetrics.shortened(text))
                    .font(Font(TabMetrics.font))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(state.edge == .left ? -90 : (state.edge == .right ? 90 : 0)))
            } else if state.showDot {
                Circle().fill(.tint).frame(width: 4, height: 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.primary.opacity(state.hovering ? 0.18 : (state.text == nil ? 0.10 : 0)))
        .glassEffect(.regular, in: shape)
        .accessibilityElement()
        .accessibilityLabel(state.text.map { "Margin. Focus task: \($0)" } ?? "Margin task list")
        .accessibilityAddTraits(.isButton)
    }
}
