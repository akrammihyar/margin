import Foundation

public struct ArchivedNote: Equatable, Identifiable, Sendable {
    public let url: URL
    public let title: String
    public let date: Date
    public var id: URL { url }
}

/// One current note, and an archive folder of saved notes.
public final class NotesStore: @unchecked Sendable {
    public let root: URL
    private let clock: @Sendable () -> Date
    private let calendar: Calendar

    public init(root: URL = Store.defaultRoot(), clock: @escaping @Sendable () -> Date = { Date() }, calendar: Calendar = .autoupdatingCurrent) {
        self.root = root; self.clock = clock; self.calendar = calendar
    }

    public var notesDirectory: URL { root.appendingPathComponent("notes", isDirectory: true) }
    public var archiveDirectory: URL { notesDirectory.appendingPathComponent("archive", isDirectory: true) }
    public var currentURL: URL { notesDirectory.appendingPathComponent("current.md") }

    public func current() throws -> String {
        guard FileManager.default.fileExists(atPath: currentURL.path) else { return "" }
        return try io { try String(contentsOf: currentURL, encoding: .utf8) }
    }

    public func setCurrent(_ text: String) throws {
        try io {
            try FileManager.default.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
            try Data(text.utf8).write(to: currentURL, options: .atomic)
        }
    }

    public func append(_ text: String) throws {
        let existing = try current()
        try setCurrent(existing.isEmpty ? text : existing + "\n" + text)
    }

    public func deleteCurrent() throws { try setCurrent("") }

    /// Saves the current note in the archive and clears it. Returns nil when the note is empty.
    @discardableResult
    public func newNote() throws -> ArchivedNote? {
        let text = try current()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let note = try archive(text)
        try setCurrent("")
        return note
    }

    /// Newest first.
    public func list() throws -> [ArchivedNote] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: archiveDirectory.path) else { return [] }
        return names.filter { $0.hasSuffix(".md") }.sorted(by: >).compactMap { name in
            let url = archiveDirectory.appendingPathComponent(name)
            guard let date = date(fromFileName: name) else { return nil }
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return ArchivedNote(url: url, title: NotesStore.title(of: text), date: date)
        }
    }

    public func read(_ note: ArchivedNote) throws -> String {
        try io { try String(contentsOf: note.url, encoding: .utf8) }
    }

    /// The saved note becomes the current note. The previous current note is archived if it is not empty.
    public func open(_ note: ArchivedNote) throws {
        let text = try read(note)
        try newNote()
        try setCurrent(text)
        try io { try FileManager.default.removeItem(at: note.url) }
    }

    public func delete(_ note: ArchivedNote) throws {
        try io { try FileManager.default.removeItem(at: note.url) }
    }

    // MARK: Helpers

    private func archive(_ text: String) throws -> ArchivedNote {
        let now = clock()
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let stamp = String(format: "%04d-%02d-%02d-%02d%02d", c.year!, c.month!, c.day!, c.hour!, c.minute!)
        let base = "\(stamp)-\(NotesStore.slug(of: text))"
        var url = archiveDirectory.appendingPathComponent("\(base).md")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = archiveDirectory.appendingPathComponent("\(base)-\(n).md")
            n += 1
        }
        try io {
            try FileManager.default.createDirectory(at: archiveDirectory, withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url, options: .atomic)
        }
        return ArchivedNote(url: url, title: NotesStore.title(of: text), date: date(fromFileName: url.lastPathComponent) ?? now)
    }

    private static func firstLine(of text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    static func title(of text: String) -> String {
        let line = firstLine(of: text)
        return line.isEmpty ? "Untitled" : String(line.prefix(60))
    }

    static func slug(of text: String) -> String {
        var out = ""
        var lastDash = true
        for ch in firstLine(of: text).lowercased() {
            if ch.isLetter || ch.isNumber {
                out.append(ch); lastDash = false
            } else if !lastDash {
                out.append("-"); lastDash = true
            }
            if out.count >= 40 { break }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out.isEmpty ? "note" : out
    }

    private func date(fromFileName name: String) -> Date? {
        // YYYY-MM-DD-HHmm
        guard name.count >= 15, let day = DayID(String(name.prefix(10))) else { return nil }
        let time = name.dropFirst(11).prefix(4)
        guard time.count == 4, let h = Int(time.prefix(2)), let m = Int(time.suffix(2)) else { return nil }
        return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: h, minute: m))
    }

    private func io<T>(_ body: () throws -> T) throws -> T {
        do { return try body() } catch let e as MarginError { throw e } catch { throw MarginError.io(error.localizedDescription) }
    }
}
