import Foundation
import Testing
@testable import MarginCommands
@testable import MarginCore

func utcCalendar() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}
func tempRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("margin-tests-\(UUID().uuidString)")
}
func makeStores() -> (Store, NotesStore) {
    let date = ISO8601DateFormatter().date(from: "2026-11-12T14:32:00Z")!
    let root = tempRoot()
    return (Store(root: root, clock: { date }, calendar: utcCalendar()), NotesStore(root: root, clock: { date }, calendar: utcCalendar()))
}

struct CLI {
    let runner: CommandRunner
    init() { let (s, n) = makeStores(); runner = CommandRunner(store: s, notes: n) }
    func callAsFunction(_ args: String...) -> CommandResult { runner.run(args) }
}

@Test func addListDone() {
    let run = CLI()
    #expect(run("add", "Call supplier").stdout == "Added 1. Call supplier\n")
    _ = run("add", "Send invoice"); #expect(run("done", "2").exitCode == 0)
    #expect(run("list").stdout == "Thu 12 Nov 2026\n 1. [ ] Call supplier\n 2. [x] Send invoice\n")
}
@Test func jsonShape() throws {
    let run = CLI()
    _ = run("add", "a"); _ = run("focus", "1")
    let obj = try JSONSerialization.jsonObject(with: Data(run("list", "--json").stdout.utf8)) as! [String: Any]
    #expect(obj["date"] as? String == "2026-11-12")
    let t = (obj["tasks"] as! [[String: Any]])[0]
    #expect(t["n"] as? Int == 1); #expect(t["text"] as? String == "a"); #expect(t["state"] as? String == "open"); #expect(t["focus"] as? Bool == true)
}
@Test func dateFlagAndMove() {
    let run = CLI()
    _ = run("add", "plan", "--date", "tomorrow"); #expect(run("list", "--date", "2026-11-13").stdout.contains("1. [ ] plan"))
    _ = run("add", "x"); _ = run("move", "x", "--to", "tomorrow")
    #expect(run("list").stdout == "Thu 12 Nov 2026\nNo tasks.\n"); #expect(run("list", "--all").stdout.contains("1. [>] x"))
}
@Test func historyDoneOnly() {
    let run = CLI()
    _ = run("add", "a", "--date", "yesterday"); _ = run("done", "a", "--date", "yesterday"); _ = run("add", "b")
    let out = run("history", "--done").stdout
    #expect(out.contains("Wed 11 Nov 2026")); #expect(out.contains("[x] a")); #expect(!out.contains("b"))
}
@Test func errorsAndUsage() {
    let run = CLI()
    #expect(run("done", "9").exitCode == 1); #expect(run("bogus").exitCode == 2); #expect(run("add").exitCode == 2)
    #expect(run("list", "--date", "soon").exitCode == 1); #expect(run().exitCode == 0)
}
@Test func notes() {
    let run = CLI()
    _ = run("note", "set", "hello"); _ = run("note", "append", "world"); #expect(run("note", "show").stdout == "hello\nworld\n")
    #expect(run("note", "new").exitCode == 0); #expect(run("note", "show").stdout == "\n"); #expect(run("note", "list").stdout.contains("hello"))
}
@Test func reorderEditRmUndoFocusClear() {
    let run = CLI()
    for t in ["a","b","c"] { _ = run("add", t) }
    _ = run("reorder", "3", "1"); _ = run("edit", "a", "A2"); _ = run("rm", "b"); _ = run("done", "c"); _ = run("undo", "c")
    _ = run("focus", "A2"); _ = run("focus", "--clear")
    #expect(run("list").stdout == "Thu 12 Nov 2026\n 1. [ ] c\n 2. [ ] A2\n")
}
@Test func focusMarkerAndTextStartingWithDashes() {
    let run = CLI()
    _ = run("add", "--", "--weird text"); _ = run("focus", "1")
    #expect(run("list").stdout == "Thu 12 Nov 2026\n 1. [ ] --weird text  ← now\n")
}
