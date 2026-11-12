import Foundation

public enum TaskState: String, Sendable {
    case open, done, archived, moved

    /// The character between the brackets in a day file.
    var marker: Character {
        switch self {
        case .open: return " "
        case .done: return "x"
        case .archived: return "~"
        case .moved: return ">"
        }
    }
}

public struct TaskItem: Equatable, Sendable {
    public var text: String
    public var state: TaskState
    /// The focus ("now") task. At most one per day.
    public var isFocus: Bool
    /// Local completion time, `HH:MM`.
    public var doneAt: String?
    /// Target day when the task was moved.
    public var movedTo: DayID?

    public init(text: String, state: TaskState = .open, isFocus: Bool = false, doneAt: String? = nil, movedTo: DayID? = nil) {
        self.text = text; self.state = state; self.isFocus = isFocus; self.doneAt = doneAt; self.movedTo = movedTo
    }
}

/// How a caller names a task of a day.
public enum TaskRef: Equatable, Sendable {
    /// 1-based position among all task lines of the day.
    case number(Int)
    /// Case-insensitive text. An exact match wins; else the fragment must match exactly one task.
    case text(String)
}

public enum MarginError: Error, Equatable, CustomStringConvertible {
    case notFound(String)
    case ambiguous(String, matches: [String])
    case emptyText
    case invalidDate(String)
    case invalidPosition(Int)
    case io(String)

    public var description: String {
        switch self {
        case .notFound(let what): return "Not found: \(what)"
        case .ambiguous(let what, let matches):
            return "\"\(what)\" matches more than one task: " + matches.map { "\"\($0)\"" }.joined(separator: ", ")
        case .emptyText: return "The text is empty."
        case .invalidDate(let s): return "Invalid date: \(s)"
        case .invalidPosition(let n): return "Invalid position: \(n)"
        case .io(let s): return "File error: \(s)"
        }
    }
}
