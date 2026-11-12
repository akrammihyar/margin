import SwiftUI
import MarginCore

struct TasksView: View {
    @Bindable var model: AppModel
    var maxListHeight: CGFloat

    @State private var listHeight: CGFloat = 0
    @State private var editing: String?
    @State private var selected: String?
    @State private var dropTarget: String?
    @FocusState private var addFocused: Bool
    @FocusState private var listFocused: Bool

    private var isToday: Bool { model.viewedDay == model.today }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DayNavigator(model: model)
            if isToday { ReviewBanner(model: model) }

            if model.rows.isEmpty {
                Text(emptyText)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(model.rows) { row in
                            TaskRow(row: row, readOnly: model.isReadOnly, isToday: isToday,
                                    isSelected: selected == row.id && listFocused, editing: $editing, model: model)
                                .overlay(alignment: .top) {
                                    if dropTarget == row.id {
                                        Capsule().fill(.tint).frame(height: 2).padding(.horizontal, 4)
                                    }
                                }
                                .draggable(row.id) {
                                    Text(row.item.text).font(.system(size: 13)).padding(6)
                                }
                                .dropDestination(for: String.self) { items, _ in
                                    guard !model.isReadOnly, let id = items.first,
                                          let source = model.rows.first(where: { $0.id == id }) else { return false }
                                    model.reorder(source, before: row)
                                    return true
                                } isTargeted: { inside in
                                    if inside { dropTarget = row.id } else if dropTarget == row.id { dropTarget = nil }
                                }
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
                }
                .frame(height: min(max(listHeight, 28), maxListHeight))
                .scrollBounceBehavior(.basedOnSize)
                .focusable()
                .focusEffectDisabled()
                .focused($listFocused)
                .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
                .onKeyPress(.downArrow) { moveSelection(1); return .handled }
                .onKeyPress(.space) { act { model.toggleDone($0) } }
                .onKeyPress(.return) { act { editing = $0.id } }
                .onKeyPress(.delete) { act { model.remove($0) } }
                .onKeyPress(.escape) { model.onRequestClose(); return .handled }
                .accessibilityLabel("Tasks")
            }

            if !model.isReadOnly {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("Add a task", text: $model.addDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($addFocused)
                        .onSubmit {
                            model.addTask()
                            addFocused = true
                        }
                        .onExitCommand { model.onRequestClose() }
                        .accessibilityLabel("Add a task")
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
        .onChange(of: model.focusRequest) { _, _ in addFocused = true }
        .onChange(of: model.viewedDay) { _, _ in editing = nil; selected = nil }
    }

    private var emptyText: String {
        if model.isReadOnly { return "No tasks on this day" }
        return isToday ? "No tasks yet" : "Nothing planned"
    }

    private func moveSelection(_ delta: Int) {
        guard !model.rows.isEmpty else { return }
        let index = model.rows.firstIndex { $0.id == selected }
        let next = min(max((index ?? (delta > 0 ? -1 : model.rows.count)) + delta, 0), model.rows.count - 1)
        selected = model.rows[next].id
    }

    private func act(_ body: (TaskRowData) -> Void) -> KeyPress.Result {
        guard !model.isReadOnly, editing == nil, let row = model.rows.first(where: { $0.id == selected }) else { return .ignored }
        body(row)
        return .handled
    }
}
