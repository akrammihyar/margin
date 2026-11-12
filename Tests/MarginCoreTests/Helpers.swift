import Foundation
@testable import MarginCore

func utcCalendar() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    c.locale = Locale(identifier: "en_GB")
    return c
}

func iso(_ s: String) -> Date {
    let f = ISO8601DateFormatter()
    return f.date(from: s)!
}

func tempRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("margin-tests-\(UUID().uuidString)")
}

func makeStore(now: String = "2026-11-12T14:32") -> Store {
    let date = iso(now + ":00Z")
    return Store(root: tempRoot(), clock: { date }, calendar: utcCalendar())
}

func makeNotes(now: String = "2026-11-12T14:32") -> NotesStore {
    let date = iso(now + ":00Z")
    return NotesStore(root: tempRoot(), clock: { date }, calendar: utcCalendar())
}
