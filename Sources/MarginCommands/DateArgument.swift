import Foundation
import MarginCore

public enum DateArgument {
    /// `today`, `tomorrow`, `yesterday`, or `YYYY-MM-DD`.
    public static func parse(_ s: String, store: Store) throws -> DayID {
        switch s.lowercased() {
        case "today": return store.today()
        case "tomorrow": return store.today().adding(days: 1, calendar: store.calendar)
        case "yesterday": return store.today().adding(days: -1, calendar: store.calendar)
        default:
            guard let day = DayID(s) else { throw MarginError.invalidDate(s) }
            return day
        }
    }
}
