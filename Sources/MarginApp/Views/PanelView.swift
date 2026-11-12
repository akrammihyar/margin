import SwiftUI
import MarginCore

enum PanelMetrics {
    static let width: CGFloat = 300
    /// Transparent space around the glass for its shadow. It also joins the tab and the panel for hover.
    static let pad: CGFloat = 20
    static let corner: CGFloat = 22
    static let edgeGap: CGFloat = 8
}

/// The content of the floating panel.
struct PanelView: View {
    @Bindable var model: AppModel
    var maxHeight: CGFloat
    var onDrag: (DragPhase) -> Void

    enum DragPhase { case began, moved, ended }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Group {
                switch model.mode {
                case .tasks: TasksView(model: model, maxListHeight: max(maxHeight - 190, 120))
                case .notes: NotesView(model: model, maxEditorHeight: max(maxHeight - 150, 160))
                }
            }
            if let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Error: \(error)")
            }
        }
        .padding(14)
        .frame(width: PanelMetrics.width)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PanelMetrics.corner, style: .continuous))
        .scaleEffect(model.panelShown || reduceMotion ? 1 : 0.92, anchor: growAnchor)
        .opacity(model.panelShown ? 1 : 0)
        .padding(PanelMetrics.pad)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The panel grows out of the edge that it is attached to.
    private var growAnchor: UnitPoint {
        switch model.panelEdge {
        case .left: return .leading
        case .right: return .trailing
        case .top: return .top
        case .bottom: return .bottom
        case nil: return .center
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Picker("View", selection: $model.mode) {
                Text("Tasks").tag(AppModel.Mode.tasks)
                Text("Notes").tag(AppModel.Mode.notes)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            // Empty area of the header: drag here to move a pinned panel.
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 22)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .global)
                        .onChanged { value in
                            onDrag(value.translation == .zero ? .began : .moved)
                        }
                        .onEnded { _ in onDrag(.ended) }
                )
                .accessibilityHidden(true)

            Button(action: { model.onTogglePin() }) {
                Image(systemName: model.isPinned ? "pin.fill" : "pin")
                    .rotationEffect(.degrees(model.isPinned ? 0 : 45))
                    .foregroundStyle(model.isPinned ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .frame(width: 24, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(model.isPinned ? "Unpin" : "Keep on top")
            .accessibilityLabel(model.isPinned ? "Unpin panel" : "Pin panel on top")
        }
        .onChange(of: model.mode) { _, _ in model.flushNote() }
    }
}
