import Foundation
import MarginCore

/// The MCP tools. Each one maps to a store operation and returns JSON text.
struct MCPTools {
    let store: Store
    let notes: NotesStore

    struct ToolError: Error { let message: String }

    private static let dateProp: [String: Any] = [
        "type": "string",
        "description": "today, tomorrow, yesterday, or YYYY-MM-DD. Default: today.",
    ]
    private static let taskProp: [String: Any] = [
        "type": ["integer", "string"],
        "description": "The task number from list_tasks, or text that matches exactly one task of that day.",
    ]

    private static func tool(_ name: String, _ description: String, _ props: [String: Any] = [:], required: [String] = []) -> [String: Any] {
        ["name": name, "description": description,
         "inputSchema": ["type": "object", "properties": props, "required": required] as [String: Any]]
    }

    static let definitions: [[String: Any]] = [
        tool("list_tasks", "List the tasks of a day in the owner's Margin task list.",
             ["date": dateProp, "include_hidden": ["type": "boolean", "description": "Also return archived and moved tasks."]]),
        tool("add_task", "Add a task to a day.", ["text": ["type": "string"], "date": dateProp], required: ["text"]),
        tool("complete_task", "Mark a task as completed.", ["task": taskProp, "date": dateProp], required: ["task"]),
        tool("reopen_task", "Mark a completed task as open again.", ["task": taskProp, "date": dateProp], required: ["task"]),
        tool("edit_task", "Change the text of a task.", ["task": taskProp, "text": ["type": "string"], "date": dateProp], required: ["task", "text"]),
        tool("delete_task", "Delete a task permanently. Use only when the owner asks.", ["task": taskProp, "date": dateProp], required: ["task"]),
        tool("move_task", "Move a task to a different day.",
             ["task": taskProp, "to": ["type": "string", "description": "Target day: today, tomorrow, yesterday, or YYYY-MM-DD."], "date": dateProp],
             required: ["task", "to"]),
        tool("reorder_task", "Move a task to a new position in the list of its day.",
             ["task": ["type": "integer", "description": "The task number."], "position": ["type": "integer", "description": "The new 1-based position."], "date": dateProp],
             required: ["task", "position"]),
        tool("set_focus", "Set the focus (\"now\") task of a day. Omit task to clear the focus.", ["task": taskProp, "date": dateProp]),
        tool("get_history", "Tasks of a range of days. Default: the last 7 days. Use filter=done for a summary of completed work.",
             ["from": dateProp, "to": dateProp, "filter": ["type": "string", "enum": ["all", "done", "open"]]]),
        tool("get_note", "Read the current note."),
        tool("set_note", "Replace the text of the current note.", ["text": ["type": "string"]], required: ["text"]),
        tool("append_note", "Add a line to the end of the current note.", ["text": ["type": "string"]], required: ["text"]),
        tool("new_note", "Save the current note in the archive and start a blank note."),
        tool("list_notes", "List the saved (archived) notes."),
    ]

    func call(_ name: String, _ args: [String: Any]) throws -> String {
        func string(_ key: String) throws -> String {
            guard let v = args[key] as? String else { throw ToolError(message: "Missing argument: \(key)") }
            return v
        }
        func day(_ key: String = "date", default fallback: String = "today") throws -> DayID {
            try DateArgument.parse((args[key] as? String) ?? fallback, store: store)
        }
        func optionalRef() -> TaskRef? {
            if let s = args["task"] as? String {
                if let n = Int(s), s.allSatisfy(\.isNumber) { return .number(n) }
                return .text(s)
            }
            if let n = args["task"] as? NSNumber { return .number(n.intValue) }
            return nil
        }
        func ref() throws -> TaskRef {
            guard let r = optionalRef() else { throw ToolError(message: "Missing argument: task") }
            return r
        }
        func int(_ key: String) throws -> Int {
            guard let n = args[key] as? NSNumber else { throw ToolError(message: "Missing argument: \(key)") }
            return n.intValue
        }
        func dayResult(_ d: DayID, hidden: Bool = true) throws -> String {
            Formatting.jsonString(Formatting.dayJSON(try store.load(d), includeHidden: hidden))
        }
        func noteResult() throws -> String { Formatting.jsonString(["text": try notes.current()]) }

        switch name {
        case "list_tasks":
            return try dayResult(try day(), hidden: (args["include_hidden"] as? Bool) ?? false)
        case "add_task":
            let d = try day(); try store.add(try string("text"), to: d); return try dayResult(d)
        case "complete_task":
            let d = try day(); try store.setDone(try ref(), true, on: d); return try dayResult(d)
        case "reopen_task":
            let d = try day(); try store.setDone(try ref(), false, on: d); return try dayResult(d)
        case "edit_task":
            let d = try day(); try store.edit(try ref(), text: try string("text"), on: d); return try dayResult(d)
        case "delete_task":
            let d = try day(); try store.remove(try ref(), on: d); return try dayResult(d)
        case "move_task":
            let d = try day(); let to = try DateArgument.parse(try string("to"), store: store)
            try store.move(try ref(), from: d, to: to); return try dayResult(to)
        case "reorder_task":
            let d = try day(); try store.reorder(try int("task"), to: try int("position"), on: d); return try dayResult(d)
        case "set_focus":
            let d = try day(); try store.setFocus(optionalRef(), on: d); return try dayResult(d)
        case "get_history":
            let to = try day("to")
            let from = try (args["from"] as? String).map { try DateArgument.parse($0, store: store) } ?? to.adding(days: -6, calendar: store.calendar)
            var filter: ((TaskItem) -> Bool)? = nil
            switch (args["filter"] as? String) ?? "all" {
            case "done": filter = { $0.state == .done }
            case "open": filter = { $0.state == .open }
            default: break
            }
            let days = try store.history(from: from, to: to)
                .filter { !Formatting.visible($0, includeHidden: false, filter: filter).isEmpty }
                .map { Formatting.dayJSON($0, includeHidden: false, filter: filter) }
            return Formatting.jsonString(["from": from.description, "to": to.description, "days": days])
        case "get_note":
            return try noteResult()
        case "set_note":
            try notes.setCurrent(try string("text")); return try noteResult()
        case "append_note":
            try notes.append(try string("text")); return try noteResult()
        case "new_note":
            let a = try notes.newNote()
            return Formatting.jsonString(["archived": a?.url.lastPathComponent as Any? ?? NSNull()])
        case "list_notes":
            return Formatting.jsonString(["notes": try notes.list().map(CommandRunner.noteJSON)])
        default:
            throw ToolError(message: "Unknown tool: \(name)")
        }
    }
}
