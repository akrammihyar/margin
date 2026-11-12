import AppKit
import Observation
import SwiftUI
import MarginCore

/// One row of the task list.
struct TaskRowData: Identifiable, Equatable {
    let number: Int
    let item: TaskItem
    var id: String { "\(number)|\(item.text)" }
}

/// The state of the app. Views read it; actions go through it to the store; then it reads the files again.
@MainActor @Observable
final class AppModel {
    enum Mode: String { case tasks, notes }

    @ObservationIgnored let store: Store
    @ObservationIgnored let notes: NotesStore

    var mode: Mode = .tasks
    var today: DayID
    var viewedDay: DayID
    var rows: [TaskRowData] = []
    var todayFocusText: String?
    var reviewDay: DayID?
    var reviewRows: [TaskRowData] = []
    var lastError: String?

    /// Text in the "Add a task" field. Kept here so that a reload cannot lose it.
    var addDraft = ""
    /// Incremented to ask the Tasks view to put the cursor in the add field.
    var focusRequest = 0
    /// True until the Tasks view has moved the cursor. The view can be created after the request.
    @ObservationIgnored var focusPending = false

    func requestAddFocus() {
        focusPending = true
        focusRequest += 1
    }

    var noteDraft = ""
    @ObservationIgnored private var noteOnDisk = ""
    var archivedNotes: [ArchivedNote] = []
    var showingAllNotes = false
    @ObservationIgnored private var pendingNoteSave: DispatchWorkItem?

    var isPinned = false
    /// Drives the open and close animation of the panel content.
    var panelShown = false
    /// The edge that the panel opens from. Nil when it is pinned.
    var panelEdge: ScreenEdge?
    @ObservationIgnored var onTogglePin: () -> Void = {}
    @ObservationIgnored var onRequestClose: () -> Void = {}
    @ObservationIgnored var onStateChange: () -> Void = {}

    init(store: Store, notes: NotesStore) {
        self.store = store
        self.notes = notes
        today = store.today()
        viewedDay = store.today()
        reload()
    }

    var isReadOnly: Bool { viewedDay < today }
    var tomorrow: DayID { today.adding(days: 1, calendar: store.calendar) }
    var noteIsDirty: Bool { noteDraft != noteOnDisk }

    // MARK: Reading

    func reload() {
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        withAnimation(reduce ? .easeInOut(duration: 0.15) : .spring(duration: 0.3)) {
            rows = taskRows(of: viewedDay) { $0.state == .open || $0.state == .done }
            let todayTasks = (try? store.load(today).tasks) ?? []
            todayFocusText = todayTasks.first(where: { $0.isFocus && $0.state == .open })?.text
            reviewDay = try? store.reviewDay(before: today)
            reviewRows = reviewDay.map { day in taskRows(of: day) { $0.state == .open } } ?? []
        }
        let disk = (try? notes.current()) ?? ""
        if !noteIsDirty { noteDraft = disk }
        noteOnDisk = disk
        archivedNotes = (try? notes.list()) ?? []
        onStateChange()
    }

    private func taskRows(of day: DayID, where keep: (TaskItem) -> Bool) -> [TaskRowData] {
        let tasks = (try? store.load(day).tasks) ?? []
        return tasks.enumerated().compactMap { keep($1) ? TaskRowData(number: $0 + 1, item: $1) : nil }
    }

    func dayDidChange() {
        let new = store.today()
        guard new != today else { reload(); return }
        if viewedDay == today { viewedDay = new }
        today = new
        reload()
    }

    // MARK: Actions

    /// Runs a store action, shows an error if it fails, then reads the files again.
    func perform(_ action: () throws -> Void) {
        do {
            try action()
            lastError = nil
        } catch let e as MarginError {
            lastError = e.description
        } catch {
            lastError = error.localizedDescription
        }
        reload()
    }

    /// The row as it is on disk now. A different process can have changed the file after the last reload.
    private func currentRef(_ row: TaskRowData, on day: DayID) throws -> TaskRef {
        let tasks = try store.load(day).tasks
        if row.number <= tasks.count, tasks[row.number - 1].text == row.item.text { return .number(row.number) }
        let matches = tasks.indices.filter { tasks[$0].text == row.item.text }
        guard matches.count == 1 else { throw MarginError.notFound("that task. The list changed") }
        return .number(matches[0] + 1)
    }

    func addTask() {
        let text = addDraft
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        perform {
            try store.add(text, to: viewedDay)
            addDraft = ""
        }
    }

    func toggleDone(_ row: TaskRowData) {
        let completing = row.item.state != .done
        perform { try store.setDone(try currentRef(row, on: viewedDay), completing, on: viewedDay) }
        if completing && lastError == nil { CompletionSound.play() }
    }

    func edit(_ row: TaskRowData, text: String) {
        do {
            let ref = try currentRef(row, on: viewedDay)
            perform { try store.edit(ref, text: text, on: viewedDay) }
        } catch {
            // The task is gone: keep the owner's text.
            addDraft = text
            lastError = "That task changed. Your text is in the add field."
            reload()
        }
    }

    func remove(_ row: TaskRowData) {
        perform { try store.remove(try currentRef(row, on: viewedDay), on: viewedDay) }
    }

    func toggleFocus(_ row: TaskRowData) {
        perform {
            if row.item.isFocus { try store.setFocus(nil, on: viewedDay) }
            else { try store.setFocus(try currentRef(row, on: viewedDay), on: viewedDay) }
        }
    }

    func moveToTomorrow(_ row: TaskRowData) {
        perform { try store.move(try currentRef(row, on: viewedDay), from: viewedDay, to: tomorrow) }
    }

    func reorder(_ row: TaskRowData, before target: TaskRowData) {
        guard row.number != target.number else { return }
        perform {
            guard case .number(let from) = try currentRef(row, on: viewedDay),
                  case .number(let to) = try currentRef(target, on: viewedDay) else { return }
            // The dragged row goes to the place above the target row.
            try store.reorder(from, to: from < to ? to - 1 : to, on: viewedDay)
        }
    }

    // MARK: Review

    func carry(_ row: TaskRowData) {
        guard let day = reviewDay else { return }
        perform { try store.carryToToday(try currentRef(row, on: day), from: day) }
    }
    func archive(_ row: TaskRowData) {
        guard let day = reviewDay else { return }
        perform { try store.archive(try currentRef(row, on: day), on: day) }
    }
    func removeFromReview(_ row: TaskRowData) {
        guard let day = reviewDay else { return }
        perform { try store.remove(try currentRef(row, on: day), on: day) }
    }
    func carryAll() {
        guard let day = reviewDay else { return }
        perform { try store.carryAll(from: day) }
    }
    func archiveAll() {
        guard let day = reviewDay else { return }
        perform { try store.archiveAll(on: day) }
    }

    // MARK: Day navigation

    func goToToday() { viewedDay = today; reload() }

    func goPrevious() {
        let days = Set((try? store.listDays()) ?? []).union([today])
        viewedDay = days.filter { $0 < viewedDay }.max() ?? viewedDay.adding(days: -1, calendar: store.calendar)
        reload()
    }

    var canGoNext: Bool { viewedDay < tomorrow }

    func goNext() {
        guard canGoNext else { return }
        let days = Set((try? store.listDays()) ?? []).union([today, tomorrow])
        viewedDay = days.filter { $0 > viewedDay && $0 <= tomorrow }.min() ?? tomorrow
        reload()
    }

    var dayTitle: String {
        let f = DateFormatter()
        f.calendar = store.calendar
        f.timeZone = store.calendar.timeZone
        let date = viewedDay.date(calendar: store.calendar).addingTimeInterval(12 * 3600)
        f.setLocalizedDateFormatFromTemplate("EEE d MMM")
        let short = f.string(from: date)
        if viewedDay == today { return "Today · \(short)" }
        if viewedDay == tomorrow { return "Tomorrow · \(short)" }
        if viewedDay == today.adding(days: -1, calendar: store.calendar) { return "Yesterday · \(short)" }
        f.setLocalizedDateFormatFromTemplate("EEE d MMM yyyy")
        return f.string(from: date)
    }

    func shortTitle(_ day: DayID) -> String {
        let f = DateFormatter()
        f.calendar = store.calendar
        f.timeZone = store.calendar.timeZone
        f.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return f.string(from: day.date(calendar: store.calendar).addingTimeInterval(12 * 3600))
    }

    // MARK: Notes

    func noteChanged() {
        pendingNoteSave?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.flushNote() }
        pendingNoteSave = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: item)
    }

    func flushNote() {
        pendingNoteSave?.cancel()
        pendingNoteSave = nil
        guard noteIsDirty else { return }
        do {
            try notes.setCurrent(noteDraft)
            noteOnDisk = noteDraft
            lastError = nil
        } catch {
            lastError = (error as? MarginError)?.description ?? error.localizedDescription
        }
    }

    func newNote() {
        flushNote()
        perform { try notes.newNote() }
    }

    func deleteCurrentNote() {
        pendingNoteSave?.cancel()
        noteDraft = ""
        noteOnDisk = ""
        perform { try notes.deleteCurrent() }
    }

    func open(_ note: ArchivedNote) {
        flushNote()
        perform { try notes.open(note) }
        showingAllNotes = false
    }

    func delete(_ note: ArchivedNote) {
        perform { try notes.delete(note) }
    }
}
