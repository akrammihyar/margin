import Foundation

extension Store {
    /// The most recent day before `day` that has one or more open tasks.
    public func reviewDay(before day: DayID) throws -> DayID? {
        for candidate in try listDays().reversed() where candidate < day {
            if try load(candidate).tasks.contains(where: { $0.state == .open }) { return candidate }
        }
        return nil
    }

    public func carryToToday(_ ref: TaskRef, from day: DayID) throws {
        try move(ref, from: day, to: today())
    }

    /// Moves every open task of `day` to today, in order.
    public func carryAll(from day: DayID) throws {
        let tasks = try load(day).tasks
        for (i, t) in tasks.enumerated() where t.state == .open {
            try move(.number(i + 1), from: day, to: today())
        }
    }

    /// Archives every open task of `day`.
    public func archiveAll(on day: DayID) throws {
        var file = try load(day)
        for i in file.lines.indices {
            if case .task(var item) = file.lines[i], item.state == .open {
                item.state = .archived
                item.isFocus = false
                file.lines[i] = .task(item)
            }
        }
        try save(file)
    }

    /// Existing days in the range, ascending, inclusive.
    public func history(from: DayID, to: DayID) throws -> [DayFile] {
        try listDays().filter { $0 >= from && $0 <= to }.map { try load($0) }
    }
}
