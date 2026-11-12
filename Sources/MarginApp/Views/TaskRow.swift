import SwiftUI
import MarginCore

struct TaskRow: View {
    let row: TaskRowData
    let readOnly: Bool
    let isToday: Bool
    let isSelected: Bool
    @Binding var editing: String?      // id of the row in edit mode
    @Bindable var model: AppModel

    @State private var hovering = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var done: Bool { row.item.state == .done }
    private var isEditing: Bool { editing == row.id }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Button(action: toggle) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(done ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .disabled(readOnly)
            .accessibilityLabel(done ? "Mark as not completed" : "Mark as completed")

            if isEditing {
                TextField("Task", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($fieldFocused)
                    .onSubmit(commit)
                    .onExitCommand { editing = nil }
                    .onAppear { draft = row.item.text; fieldFocused = true }
            } else {
                Text(row.item.text)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .opacity(done ? 0.45 : 1)
                    .overlay(alignment: .leading) {
                        // The cross-off line grows from the leading edge.
                        Rectangle()
                            .frame(height: 1.5)
                            .foregroundStyle(.primary.opacity(0.55))
                            .scaleEffect(x: done ? 1 : 0, y: 1, anchor: .leading)
                            .opacity(reduceMotion ? (done ? 1 : 0) : 1)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if row.item.isFocus && !isEditing {
                Text("now")
                    .font(.system(size: 9, weight: .semibold))
                    .textCase(.uppercase)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tint, in: Capsule())
                    .foregroundStyle(.white)
                    .accessibilityLabel("Focus task")
            }

            if hovering && !readOnly && !isEditing {
                HStack(spacing: 2) {
                    if !done {
                        hoverButton(row.item.isFocus ? "scope" : "scope", label: row.item.isFocus ? "Remove focus" : "Focus on this") {
                            model.toggleFocus(row)
                        }
                    }
                    hoverButton("pencil", label: "Edit") { editing = row.id }
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.primary.opacity(isSelected ? 0.10 : (row.item.isFocus ? 0.06 : (hovering ? 0.04 : 0))))
        )
        .contentShape(Rectangle())
        .onTapGesture { if !isEditing { toggle() } }
        .onHover { hovering = $0 }
        .contextMenu { if !readOnly { menu } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.item.text), \(done ? "completed" : "open")\(row.item.isFocus ? ", focus task" : "")")
        .accessibilityAddTraits(.isButton)
    }

    private func toggle() {
        guard !readOnly else { return }
        model.toggleDone(row)
    }

    private func commit() {
        let text = draft
        editing = nil
        if text.trimmingCharacters(in: .whitespaces) != row.item.text { model.edit(row, text: text) }
    }

    private func hoverButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    @ViewBuilder private var menu: some View {
        if !done {
            Button(row.item.isFocus ? "Remove Focus" : "Focus on This") { model.toggleFocus(row) }
        }
        Button("Edit") { editing = row.id }
        if isToday && !done {
            Button("Move to Tomorrow") { model.moveToTomorrow(row) }
        }
        Divider()
        Button("Delete", role: .destructive) { model.remove(row) }
    }
}
