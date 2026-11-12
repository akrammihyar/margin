import Foundation
import MarginCore

public struct CommandResult: Equatable {
    public var exitCode: Int32
    public var stdout: String
    public var stderr: String
    public init(exitCode: Int32 = 0, stdout: String = "", stderr: String = "") {
        self.exitCode = exitCode; self.stdout = stdout; self.stderr = stderr
    }
}

/// Runs one `margin` command. See `usage` for the commands.
public struct CommandRunner {
    let store: Store
    let notes: NotesStore

    public init(store: Store, notes: NotesStore) {
        self.store = store; self.notes = notes
    }

    public static let usage = """
    margin — the task list of the day (\(AppInfo.name) \(AppInfo.version))

    Usage:
      margin list [--date D] [--all]             tasks of a day (--all shows archived and moved tasks)
      margin add "text" [--date D]
      margin done <n|text> [--date D]
      margin undo <n|text> [--date D]            reopen a task
      margin edit <n|text> "new text" [--date D]
      margin rm <n|text> [--date D]
      margin move <n|text> --to D [--date D]
      margin reorder <n> <new position> [--date D]
      margin focus <n|text> | --clear
      margin history [--from D] [--to D] [--done|--open]   default: the last 7 days
      margin note show | set "text" | append "text" | new | list
      margin mcp                                 start the MCP server (stdio)
      margin path                                print the data folder

    D is today, tomorrow, yesterday, or YYYY-MM-DD (default: today).
    <n|text> is a task number from `margin list`, or text that matches one task.
    Add --json for JSON output.

    """

    private struct UsageError: Error { let message: String }

    private struct Parsed {
        var positionals: [String] = []
        var values: [String: String] = [:]
        var flags: Set<String> = []
    }

    private static let valueFlags: Set<String> = ["--date", "--to", "--from"]
    private static let boolFlags: Set<String> = ["--json", "--all", "--done", "--open", "--clear"]

    private func parse(_ args: [String]) throws -> Parsed {
        var p = Parsed()
        var i = 0
        var literal = false
        while i < args.count {
            let a = args[i]
            if literal {
                p.positionals.append(a)
            } else if a == "--" {
                literal = true
            } else if CommandRunner.valueFlags.contains(a) {
                guard i + 1 < args.count else { throw UsageError(message: "\(a) needs a value.") }
                p.values[a] = args[i + 1]
                i += 1
            } else if CommandRunner.boolFlags.contains(a) {
                p.flags.insert(a)
            } else if a.hasPrefix("--") {
                throw UsageError(message: "Unknown option: \(a)")
            } else {
                p.positionals.append(a)
            }
            i += 1
        }
        return p
    }

    private func ref(_ s: String) -> TaskRef {
        if let n = Int(s), s.allSatisfy(\.isNumber) { return .number(n) }
        return .text(s)
    }

    public func run(_ args: [String]) -> CommandResult {
        guard let command = args.first, command != "help", command != "--help", command != "-h" else {
            return CommandResult(stdout: CommandRunner.usage)
        }
        do {
            let p = try parse(Array(args.dropFirst()))
            let json = p.flags.contains("--json")
            let day = try DateArgument.parse(p.values["--date"] ?? "today", store: store)

            /// Output after a change: one confirmation line, or the day as JSON.
            func changed(_ message: String, day shown: DayID? = nil) throws -> CommandResult {
                if json {
                    return CommandResult(stdout: Formatting.jsonString(Formatting.dayJSON(try store.load(shown ?? day), includeHidden: true)) + "\n")
                }
                return CommandResult(stdout: message + "\n")
            }
            func need(_ count: Int, _ hint: String) throws {
                guard p.positionals.count == count else { throw UsageError(message: "Usage: margin \(hint)") }
            }

            switch command {
            case "list":
                try need(0, "list [--date D] [--all]")
                let file = try store.load(day)
                let all = p.flags.contains("--all")
                if json { return CommandResult(stdout: Formatting.jsonString(Formatting.dayJSON(file, includeHidden: all)) + "\n") }
                return CommandResult(stdout: Formatting.dayText(file, includeHidden: all, filter: nil, calendar: store.calendar))

            case "add":
                try need(1, "add \"text\" [--date D]")
                let n = try store.add(p.positionals[0], to: day)
                let item = try store.task(.number(n), on: day).item
                return try changed("Added \(n). \(item.text)")

            case "done", "undo":
                try need(1, "\(command) <n|text> [--date D]")
                let t = try store.task(ref(p.positionals[0]), on: day)
                try store.setDone(.number(t.number), command == "done", on: day)
                return try changed((command == "done" ? "Done: " : "Reopened: ") + t.item.text)

            case "edit":
                try need(2, "edit <n|text> \"new text\" [--date D]")
                let t = try store.task(ref(p.positionals[0]), on: day)
                try store.edit(.number(t.number), text: p.positionals[1], on: day)
                return try changed("Edited \(t.number). \(try store.task(.number(t.number), on: day).item.text)")

            case "rm":
                try need(1, "rm <n|text> [--date D]")
                let t = try store.task(ref(p.positionals[0]), on: day)
                try store.remove(.number(t.number), on: day)
                return try changed("Removed: \(t.item.text)")

            case "move":
                try need(1, "move <n|text> --to D [--date D]")
                guard let toText = p.values["--to"] else { throw UsageError(message: "Usage: margin move <n|text> --to D [--date D]") }
                let to = try DateArgument.parse(toText, store: store)
                let t = try store.task(ref(p.positionals[0]), on: day)
                try store.move(.number(t.number), from: day, to: to)
                return try changed("Moved to \(to): \(t.item.text)", day: to)

            case "reorder":
                try need(2, "reorder <n> <new position> [--date D]")
                guard let from = Int(p.positionals[0]), let to = Int(p.positionals[1]) else {
                    throw UsageError(message: "Usage: margin reorder <n> <new position> [--date D]")
                }
                try store.reorder(from, to: to, on: day)
                return try changed("Moved task \(from) to position \(to)")

            case "focus":
                if p.flags.contains("--clear") {
                    try need(0, "focus <n|text> | --clear")
                    try store.setFocus(nil, on: day)
                    return try changed("Focus cleared")
                }
                try need(1, "focus <n|text> | --clear")
                let t = try store.task(ref(p.positionals[0]), on: day)
                try store.setFocus(.number(t.number), on: day)
                return try changed("Focus: \(t.item.text)")

            case "history":
                try need(0, "history [--from D] [--to D] [--done|--open]")
                let to = try DateArgument.parse(p.values["--to"] ?? "today", store: store)
                let from = try p.values["--from"].map { try DateArgument.parse($0, store: store) }
                    ?? to.adding(days: -6, calendar: store.calendar)
                var filter: ((TaskItem) -> Bool)? = nil
                if p.flags.contains("--done") { filter = { $0.state == .done } }
                if p.flags.contains("--open") { filter = { $0.state == .open } }
                let days = try store.history(from: from, to: to).filter {
                    !Formatting.visible($0, includeHidden: false, filter: filter).isEmpty
                }
                if json {
                    return CommandResult(stdout: Formatting.jsonString(days.map { Formatting.dayJSON($0, includeHidden: false, filter: filter) }) + "\n")
                }
                if days.isEmpty { return CommandResult(stdout: "No tasks from \(from) to \(to).\n") }
                let text = days.map { Formatting.dayText($0, includeHidden: false, filter: filter, calendar: store.calendar) }.joined(separator: "\n")
                return CommandResult(stdout: text)

            case "note":
                return try runNote(p, json: json)

            case "path":
                return CommandResult(stdout: store.root.path + "\n")

            default:
                return CommandResult(exitCode: 2, stderr: "Unknown command: \(command)\n\n" + CommandRunner.usage)
            }
        } catch let e as UsageError {
            return CommandResult(exitCode: 2, stderr: e.message + "\n")
        } catch let e as MarginError {
            return CommandResult(exitCode: 1, stderr: e.description + "\n")
        } catch {
            return CommandResult(exitCode: 1, stderr: error.localizedDescription + "\n")
        }
    }

    private func runNote(_ p: Parsed, json: Bool) throws -> CommandResult {
        let usage = "Usage: margin note show | set \"text\" | append \"text\" | new | list"
        guard let sub = p.positionals.first else { throw UsageError(message: usage) }
        let rest = Array(p.positionals.dropFirst())
        func show() throws -> CommandResult {
            let text = try notes.current()
            return CommandResult(stdout: json ? Formatting.jsonString(["text": text]) + "\n" : text + "\n")
        }
        switch (sub, rest.count) {
        case ("show", 0):
            return try show()
        case ("set", 1):
            try notes.setCurrent(rest[0])
            return json ? try show() : CommandResult(stdout: "Note saved\n")
        case ("append", 1):
            try notes.append(rest[0])
            return json ? try show() : CommandResult(stdout: "Note updated\n")
        case ("new", 0):
            let archived = try notes.newNote()
            if json { return CommandResult(stdout: Formatting.jsonString(["archived": archived?.url.lastPathComponent as Any? ?? NSNull()]) + "\n") }
            return CommandResult(stdout: archived.map { "Saved: \($0.url.lastPathComponent)\n" } ?? "The current note is empty.\n")
        case ("list", 0):
            let all = try notes.list()
            if json { return CommandResult(stdout: Formatting.jsonString(["notes": all.map(CommandRunner.noteJSON)]) + "\n") }
            if all.isEmpty { return CommandResult(stdout: "No saved notes.\n") }
            return CommandResult(stdout: all.map { "\($0.url.lastPathComponent)  \($0.title)" }.joined(separator: "\n") + "\n")
        default:
            throw UsageError(message: usage)
        }
    }

    static func noteJSON(_ n: ArchivedNote) -> [String: Any] {
        ["file": n.url.lastPathComponent, "title": n.title, "path": n.url.path]
    }
}
