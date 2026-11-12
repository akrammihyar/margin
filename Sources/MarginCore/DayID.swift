import Foundation

/// A calendar day, independent of time zone. Text form: `YYYY-MM-DD`.
public struct DayID: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Accepts only `YYYY-MM-DD` with a date that exists.
    public init?(_ string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy(\.isASCIIDigit) }),
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = DateComponents(calendar: cal, timeZone: cal.timeZone, year: y, month: m, day: d)
        guard comps.isValidDate(in: cal) else { return nil }
        year = y; month = m; day = d
    }

    public init(date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        year = c.year!; month = c.month!; day = c.day!
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Noon of this day in the calendar's time zone. Noon avoids daylight-saving edge cases.
    private func noon(calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// Local midnight at the start of this day.
    public func date(calendar: Calendar) -> Date {
        calendar.startOfDay(for: noon(calendar: calendar))
    }

    public func adding(days: Int, calendar: Calendar) -> DayID {
        let moved = calendar.date(byAdding: .day, value: days, to: noon(calendar: calendar))!
        return DayID(date: moved, calendar: calendar)
    }

    public static func < (a: DayID, b: DayID) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }
}

extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
