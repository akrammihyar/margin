import Foundation

/// One line of a day file. Lines that are not tasks are kept as they are.
public enum DayLine: Equatable, Sendable {
    case task(TaskItem)
    case other(String)
}

/// The content of one day file. See docs/DATA-FORMAT.md.
public struct DayFile: Equatable, Sendable {
    public let day: DayID
    public var lines: [DayLine]

    /// A new, empty day: a header line and a blank line.
    public init(day: DayID) {
        self.day = day
        self.lines = [.other("# \(day)"), .other("")]
    }

    init(day: DayID, lines: [DayLine]) {
        self.day = day
        self.lines = lines
    }

    /// Task lines in file order.
    public var tasks: [TaskItem] {
        lines.compactMap { if case .task(let t) = $0 { return t } else { return nil } }
    }

    /// Index into `lines` of the task with 0-based position `n` among the task lines.
    public func lineIndex(ofTask n: Int) -> Int? {
        var seen = 0
        for (i, line) in lines.enumerated() {
            if case .task = line {
                if seen == n { return i }
                seen += 1
            }
        }
        return nil
    }

    // MARK: Parse

    public static func parse(_ text: String, day: DayID) -> DayFile {
        var raw = text.components(separatedBy: "\n")
        if raw.last == "" { raw.removeLast() }
        var focusSeen = false
        let lines: [DayLine] = raw.map { original in
            var line = original
            if line.hasSuffix("\r") { line.removeLast() }
            guard var item = parseTaskLine(line) else { return .other(line) }
            if item.isFocus {
                if focusSeen { item.isFocus = false } else { focusSeen = true }
            }
            return .task(item)
        }
        return DayFile(day: day, lines: lines)
    }

    /// Matches `^\s*[-*]\s+\[( |x|X|~|>)\]\s+(.*)$`.
    private static func parseTaskLine(_ line: String) -> TaskItem? {
        var s = Substring(line).drop(while: { $0 == " " || $0 == "\t" })
        guard let bullet = s.first, bullet == "-" || bullet == "*" else { return nil }
        s = s.dropFirst()
        let afterBullet = s.drop(while: { $0 == " " || $0 == "\t" })
        guard afterBullet.startIndex != s.startIndex else { return nil }
        s = afterBullet
        guard s.count >= 3, s.first == "[" else { return nil }
        let marker = s[s.index(after: s.startIndex)]
        guard s[s.index(s.startIndex, offsetBy: 2)] == "]" else { return nil }
        let state: TaskState
        switch marker {
        case " ": state = .open
        case "x", "X": state = .done
        case "~": state = .archived
        case ">": state = .moved
        default: return nil
        }
        s = s.dropFirst(3)
        let afterBox = s.drop(while: { $0 == " " || $0 == "\t" })
        guard afterBox.startIndex != s.startIndex else { return nil }

        var item = TaskItem(text: "", state: state)
        var body = String(afterBox).trimmingCharacters(in: .whitespaces)
        // Strip tags from the end, in any order.
        while true {
            guard let tag = lastWord(of: body) else { break }
            if tag == "@now" {
                item.isFocus = true
            } else if let v = tagValue(tag, name: "done"), isClockTime(v) {
                item.doneAt = v
            } else if let v = tagValue(tag, name: "moved"), let d = DayID(v) {
                item.movedTo = d
            } else {
                break
            }
            body = String(body.dropLast(tag.count)).trimmingCharacters(in: .whitespaces)
        }
        item.text = body
        return item
    }

    private static func lastWord(of s: String) -> String? {
        guard !s.isEmpty else { return nil }
        if let space = s.lastIndex(where: { $0 == " " || $0 == "\t" }) {
            return String(s[s.index(after: space)...])
        }
        return s
    }

    private static func tagValue(_ tag: String, name: String) -> String? {
        let prefix = "@\(name)("
        guard tag.hasPrefix(prefix), tag.hasSuffix(")") else { return nil }
        return String(tag.dropFirst(prefix.count).dropLast())
    }

    private static func isClockTime(_ s: String) -> Bool {
        let p = s.split(separator: ":", omittingEmptySubsequences: false)
        guard p.count == 2, (1...2).contains(p[0].count), p[1].count == 2,
              let h = Int(p[0]), let m = Int(p[1]) else { return false }
        return (0..<24).contains(h) && (0..<60).contains(m)
    }

    // MARK: Render

    public func render() -> String {
        guard !lines.isEmpty else { return "" }
        return lines.map { line -> String in
            switch line {
            case .other(let s): return s
            case .task(let t): return DayFile.render(t)
            }
        }.joined(separator: "\n") + "\n"
    }

    static func render(_ t: TaskItem) -> String {
        var s = "- [\(t.state.marker)] \(t.text)"
        if t.isFocus && t.state == .open { s += " @now" }
        if let d = t.doneAt { s += " @done(\(d))" }
        if let m = t.movedTo { s += " @moved(\(m))" }
        return s
    }
}
