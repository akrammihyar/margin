import Foundation

/// Reads and writes day files. Every operation reads the file from disk again
/// immediately before it changes it, and writes atomically, so that the app,
/// the CLI, and agents can all change the same files.
public final class Store: @unchecked Sendable {
    public let root: URL
    public let calendar: Calendar
    private let clock: @Sendable () -> Date

    public init(root: URL = Store.defaultRoot(), clock: @escaping @Sendable () -> Date = { Date() }, calendar: Calendar = .current) {
        self.root = root
        self.clock = clock
        self.calendar = calendar
    }

    /// `$MARGIN_HOME`, or `~/Margin`.
    public static func defaultRoot() -> URL {
        if let custom = ProcessInfo.processInfo.environment["MARGIN_HOME"], !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(AppInfo.name, isDirectory: true)
    }

    public func now() -> Date { clock() }
    public func today() -> DayID { DayID(date: clock(), calendar: calendar) }

    public var daysDirectory: URL { root.appendingPathComponent("days", isDirectory: true) }
    public func url(for day: DayID) -> URL { daysDirectory.appendingPathComponent("\(day).md") }

    // MARK: Files

    /// A missing file reads as a new, empty day. Nothing is written.
    public func load(_ day: DayID) throws -> DayFile {
        let url = url(for: day)
        guard FileManager.default.fileExists(atPath: url.path) else { return DayFile(day: day) }
        do {
            return DayFile.parse(try String(contentsOf: url, encoding: .utf8), day: day)
        } catch {
            throw MarginError.io(error.localizedDescription)
        }
    }

    public func save(_ file: DayFile) throws {
        do {
            try FileManager.default.createDirectory(at: daysDirectory, withIntermediateDirectories: true)
            try Data(file.render().utf8).write(to: url(for: file.day), options: .atomic)
        } catch {
            throw MarginError.io(error.localizedDescription)
        }
    }

    /// Existing day files, ascending. Other files in the folder are ignored.
    public func listDays() throws -> [DayID] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: daysDirectory.path) else { return [] }
        return names.compactMap { name -> DayID? in
            guard name.hasSuffix(".md") else { return nil }
            return DayID(String(name.dropLast(3)))
        }.sorted()
    }

    // MARK: Operations

    /// Line breaks become spaces; the result is trimmed. Empty text is an error.
    public static func normalize(_ text: String) throws -> String {
        let oneLine = text.components(separatedBy: .newlines).joined(separator: " ")
        let collapsed = oneLine.trimmingCharacters(in: .whitespaces)
        guard !collapsed.isEmpty else { throw MarginError.emptyText }
        return collapsed
    }

    /// Adds an open task at the end of the day's tasks. Returns its 1-based number.
    @discardableResult
    public func add(_ text: String, to day: DayID) throws -> Int {
        let clean = try Store.normalize(text)
        var file = try load(day)
        let count = file.tasks.count
        let item = DayLine.task(TaskItem(text: clean))
        if count > 0, let last = file.lineIndex(ofTask: count - 1) {
            file.lines.insert(item, at: last + 1)
        } else {
            file.lines.append(item)
        }
        try save(file)
        return count + 1
    }

    public func setDone(_ ref: TaskRef, _ done: Bool, on day: DayID) throws {
        try update(ref, on: day) { item in
            if done {
                item.state = .done
                item.isFocus = false
                item.movedTo = nil
                let c = self.calendar.dateComponents([.hour, .minute], from: self.clock())
                item.doneAt = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
            } else {
                item.state = .open
                item.doneAt = nil
                item.movedTo = nil
            }
        }
    }

    public func edit(_ ref: TaskRef, text: String, on day: DayID) throws {
        let clean = try Store.normalize(text)
        try update(ref, on: day) { $0.text = clean }
    }

    public func archive(_ ref: TaskRef, on day: DayID) throws {
        try update(ref, on: day) { item in
            item.state = .archived
            item.isFocus = false
        }
    }

    public func remove(_ ref: TaskRef, on day: DayID) throws {
        var file = try load(day)
        let line = try resolve(ref, in: file)
        file.lines.remove(at: line)
        try save(file)
    }

    /// The task is added as open to `to`; in `from` it is marked moved.
    public func move(_ ref: TaskRef, from: DayID, to: DayID) throws {
        guard from != to else { throw MarginError.invalidDate("\(to) is the same day") }
        var source = try load(from)
        let line = try resolve(ref, in: source)
        guard case .task(var item) = source.lines[line] else { return }
        // Write the target first: a failure between the two writes then gives a duplicate, not a loss.
        try add(item.text, to: to)
        item.state = .moved
        item.isFocus = false
        item.doneAt = nil
        item.movedTo = to
        source.lines[line] = .task(item)
        try save(source)
    }

    /// Moves a task among the task lines. Lines that are not tasks keep their places.
    public func reorder(_ number: Int, to newNumber: Int, on day: DayID) throws {
        var file = try load(day)
        var tasks = file.tasks
        guard (1...max(tasks.count, 1)).contains(number), number <= tasks.count else { throw MarginError.invalidPosition(number) }
        guard newNumber >= 1, newNumber <= tasks.count else { throw MarginError.invalidPosition(newNumber) }
        let moving = tasks.remove(at: number - 1)
        tasks.insert(moving, at: newNumber - 1)
        var next = 0
        for i in file.lines.indices {
            if case .task = file.lines[i] {
                file.lines[i] = .task(tasks[next])
                next += 1
            }
        }
        try save(file)
    }

    /// Sets the focus task of the day. `nil` clears it. Only an open task can have the focus.
    public func setFocus(_ ref: TaskRef?, on day: DayID) throws {
        var file = try load(day)
        var target: Int? = nil
        if let ref {
            let line = try resolve(ref, in: file)
            guard case .task(let item) = file.lines[line], item.state == .open else {
                throw MarginError.notFound("an open task for the focus")
            }
            target = line
        }
        for i in file.lines.indices {
            if case .task(var item) = file.lines[i] {
                item.isFocus = (i == target)
                file.lines[i] = .task(item)
            }
        }
        try save(file)
    }

    // MARK: Helpers

    private func update(_ ref: TaskRef, on day: DayID, _ change: (inout TaskItem) -> Void) throws {
        var file = try load(day)
        let line = try resolve(ref, in: file)
        guard case .task(var item) = file.lines[line] else { return }
        change(&item)
        file.lines[line] = .task(item)
        try save(file)
    }

    /// Returns the index into `file.lines` of the task that `ref` names.
    func resolve(_ ref: TaskRef, in file: DayFile) throws -> Int {
        switch ref {
        case .number(let n):
            guard n >= 1, let line = file.lineIndex(ofTask: n - 1) else { throw MarginError.notFound("task \(n) on \(file.day)") }
            return line
        case .text(let fragment):
            let needle = fragment.trimmingCharacters(in: .whitespaces).lowercased()
            guard !needle.isEmpty else { throw MarginError.emptyText }
            let tasks = file.tasks
            let exact = tasks.indices.filter { tasks[$0].text.lowercased() == needle }
            let candidates = exact.count == 1 ? exact : tasks.indices.filter { tasks[$0].text.lowercased().contains(needle) }
            if candidates.isEmpty { throw MarginError.notFound("a task with \"\(fragment)\" on \(file.day)") }
            if candidates.count > 1 { throw MarginError.ambiguous(fragment, matches: candidates.map { tasks[$0].text }) }
            return file.lineIndex(ofTask: candidates[0])!
        }
    }
}

extension Store {
    /// The task that `ref` names, with its 1-based number.
    public func task(_ ref: TaskRef, on day: DayID) throws -> (number: Int, item: TaskItem) {
        let file = try load(day)
        let line = try resolve(ref, in: file)
        var number = 0
        for i in 0...line { if case .task = file.lines[i] { number += 1 } }
        guard case .task(let item) = file.lines[line] else { throw MarginError.notFound("task") }
        return (number, item)
    }
}
