import Foundation
import MarginCore

public enum Formatting {
    public static func taskJSON(_ t: TaskItem, number: Int) -> [String: Any] {
        var o: [String: Any] = ["n": number, "text": t.text, "state": t.state.rawValue, "focus": t.isFocus]
        if let d = t.doneAt { o["done_at"] = d }
        if let m = t.movedTo { o["moved_to"] = m.description }
        return o
    }

    static func visible(_ f: DayFile, includeHidden: Bool, filter: ((TaskItem) -> Bool)? = nil) -> [(Int, TaskItem)] {
        f.tasks.enumerated().compactMap { i, t in
            if !includeHidden && (t.state == .archived || t.state == .moved) { return nil }
            if let filter, !filter(t) { return nil }
            return (i + 1, t)
        }
    }

    public static func dayJSON(_ f: DayFile, includeHidden: Bool) -> [String: Any] {
        dayJSON(f, includeHidden: includeHidden, filter: nil)
    }

    static func dayJSON(_ f: DayFile, includeHidden: Bool, filter: ((TaskItem) -> Bool)?) -> [String: Any] {
        ["date": f.day.description,
         "tasks": visible(f, includeHidden: includeHidden, filter: filter).map { taskJSON($0.1, number: $0.0) }]
    }

    /// For example `Thu 12 Nov 2026`.
    public static func dayTitle(_ day: DayID, calendar: Calendar) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "EEE d MMM yyyy"
        return f.string(from: day.date(calendar: calendar).addingTimeInterval(12 * 3600))
    }

    public static func dayText(_ f: DayFile, includeHidden: Bool) -> String {
        dayText(f, includeHidden: includeHidden, filter: nil, calendar: Calendar(identifier: .gregorian))
    }

    static func dayText(_ f: DayFile, includeHidden: Bool, filter: ((TaskItem) -> Bool)?, calendar: Calendar) -> String {
        var out = dayTitle(f.day, calendar: calendar) + "\n"
        let rows = visible(f, includeHidden: includeHidden, filter: filter)
        if rows.isEmpty { return out + "No tasks.\n" }
        for (n, t) in rows {
            out += String(format: "%2d. ", n) + "[\(marker(t.state))] \(t.text)" + (t.isFocus ? "  ← now" : "") + "\n"
        }
        return out
    }

    static func marker(_ s: TaskState) -> String {
        switch s {
        case .open: return " "
        case .done: return "x"
        case .archived: return "~"
        case .moved: return ">"
        }
    }

    public static func jsonString(_ object: Any) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data("null".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}
