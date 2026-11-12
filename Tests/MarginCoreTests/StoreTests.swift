import Foundation
import Testing
@testable import MarginCore

@Test func addCreatesFileWithHeader() throws {
    let s = makeStore(); let n = try s.add("Call supplier", to: s.today())
    #expect(n == 1)
    #expect(try String(contentsOf: s.url(for: s.today()), encoding: .utf8) == "# 2026-11-12\n\n- [ ] Call supplier\n")
}
@Test func addNormalizesAndRejectsEmpty() throws {
    let s = makeStore(); try s.add("  line one\nline two \r\n", to: s.today())
    #expect(try s.load(s.today()).tasks[0].text == "line one line two")
    #expect(throws: MarginError.emptyText) { try s.add(" \n ", to: s.today()) }
}
@Test func doneSetsTimeAndClearsFocus() throws {
    let s = makeStore(); try s.add("a", to: s.today()); try s.setFocus(.number(1), on: s.today())
    try s.setDone(.number(1), true, on: s.today())
    let t = try s.load(s.today()).tasks[0]
    #expect(t.state == .done); #expect(t.doneAt == "14:32"); #expect(!t.isFocus)
    try s.setDone(.text("A"), false, on: s.today())
    #expect(try s.load(s.today()).tasks[0] == TaskItem(text: "a"))
}
@Test func focusIsSingle() throws {
    let s = makeStore(); for t in ["a","b"] { try s.add(t, to: s.today()) }
    try s.setFocus(.number(1), on: s.today()); try s.setFocus(.number(2), on: s.today())
    #expect(try s.load(s.today()).tasks.map(\.isFocus) == [false, true])
    try s.setFocus(nil, on: s.today()); #expect(try s.load(s.today()).tasks.allSatisfy { !$0.isFocus })
}
@Test func moveMarksSourceAndAppendsToTarget() throws {
    let s = makeStore(); try s.add("a", to: s.today()); let tomorrow = DayID("2026-11-13")!
    try s.move(.number(1), from: s.today(), to: tomorrow)
    #expect(try s.load(s.today()).tasks[0].state == .moved); #expect(try s.load(s.today()).tasks[0].movedTo == tomorrow)
    #expect(try s.load(tomorrow).tasks == [TaskItem(text: "a")])
}
@Test func reorderKeepsOtherLines() throws {
    let s = makeStore()
    try FileManager.default.createDirectory(at: s.url(for: s.today()).deletingLastPathComponent(), withIntermediateDirectories: true)
    try "# h\n- [ ] a\nnote\n- [ ] b\n- [ ] c\n".write(to: s.url(for: s.today()), atomically: true, encoding: .utf8)
    try s.reorder(3, to: 1, on: s.today())
    #expect(try String(contentsOf: s.url(for: s.today()), encoding: .utf8) == "# h\n- [ ] c\nnote\n- [ ] a\n- [ ] b\n")
    #expect(throws: MarginError.invalidPosition(9)) { try s.reorder(1, to: 9, on: s.today()) }
}
@Test func refErrors() throws {
    let s = makeStore(); for t in ["call bank","call supplier"] { try s.add(t, to: s.today()) }
    #expect(throws: MarginError.self) { try s.setDone(.text("call"), true, on: s.today()) }
    #expect(throws: MarginError.self) { try s.setDone(.number(5), true, on: s.today()) }
    try s.setDone(.text("SUPPLIER"), true, on: s.today()); #expect(try s.load(s.today()).tasks[1].state == .done)
}
@Test func operationRereadsDisk() throws {
    let s = makeStore(); try s.add("a", to: s.today())
    let url = s.url(for: s.today())
    try (String(contentsOf: url, encoding: .utf8) + "- [ ] from agent\n").write(to: url, atomically: true, encoding: .utf8)
    try s.add("b", to: s.today())
    #expect(try s.load(s.today()).tasks.map(\.text) == ["a","from agent","b"])
}
@Test func missingFolderIsRecreated() throws {
    let s = makeStore(); try s.add("a", to: s.today()); try FileManager.default.removeItem(at: s.root)
    #expect(try s.load(s.today()).tasks.isEmpty); #expect(try s.listDays().isEmpty)
    try s.add("b", to: s.today()); #expect(try s.load(s.today()).tasks.map(\.text) == ["b"])
}
@Test func listDaysIgnoresOtherFiles() throws {
    let s = makeStore(); try s.add("a", to: DayID("2026-11-10")!); try s.add("b", to: s.today())
    try "x".write(to: s.root.appendingPathComponent("days/readme.md"), atomically: true, encoding: .utf8)
    #expect(try s.listDays().map(\.description) == ["2026-11-10","2026-11-12"])
}
@Test func removeAndArchiveAndEdit() throws {
    let s = makeStore(); for t in ["a","b","c"] { try s.add(t, to: s.today()) }
    try s.archive(.number(1), on: s.today()); try s.edit(.number(2), text: "B2", on: s.today()); try s.remove(.number(3), on: s.today())
    #expect(try String(contentsOf: s.url(for: s.today()), encoding: .utf8) == "# 2026-11-12\n\n- [~] a\n- [ ] B2\n")
}
@Test func exactTextMatchWinsOverFragment() throws {
    let s = makeStore(); for t in ["plan", "plan next week"] { try s.add(t, to: s.today()) }
    try s.setDone(.text("plan"), true, on: s.today())
    #expect(try s.load(s.today()).tasks.map(\.state) == [.done, .open])
}

// Review and history

@Test func reviewDaySkipsDaysWithoutOpenTasks() throws {
    let s = makeStore(now: "2026-11-16T09:00")
    try s.add("old", to: DayID("2026-11-11")!)
    try s.add("fri", to: DayID("2026-11-13")!)
    try s.add("done", to: DayID("2026-11-14")!); try s.setDone(.number(1), true, on: DayID("2026-11-14")!)
    try s.add("future", to: DayID("2026-11-17")!)
    #expect(try s.reviewDay(before: s.today()) == DayID("2026-11-13"))
    try s.archiveAll(on: DayID("2026-11-13")!)
    #expect(try s.reviewDay(before: s.today()) == DayID("2026-11-11"))
    try s.carryAll(from: DayID("2026-11-11")!)
    #expect(try s.reviewDay(before: s.today()) == nil)
    #expect(try s.load(s.today()).tasks.map(\.text) == ["old"])
}
@Test func todayFollowsClockAndTimeZone() {
    var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Makassar")!
    let s = Store(root: tempRoot(), clock: { iso("2026-11-12T17:30:00Z") }, calendar: cal)
    #expect(s.today().description == "2026-11-13")
}
@Test func historyRangeInclusiveAscending() throws {
    let s = makeStore(); for d in ["2026-11-08","2026-11-10","2026-11-12"] { try s.add("t", to: DayID(d)!) }
    #expect(try s.history(from: DayID("2026-11-09")!, to: DayID("2026-11-12")!).map(\.day.description) == ["2026-11-10","2026-11-12"])
}

// Findings of the 1.0 review

@Test func focusTagOnDoneTaskDoesNotTakeTheFocus() {
    let f = DayFile.parse("- [x] old @now\n- [ ] real @now\n", day: DayID("2026-11-12")!)
    #expect(f.tasks.map(\.isFocus) == [false, true])
}
@Test func onlyOpenTasksCanMove() throws {
    let s = makeStore(); try s.add("a", to: s.today()); try s.setDone(.number(1), true, on: s.today())
    #expect(throws: MarginError.self) { try s.move(.number(1), from: s.today(), to: DayID("2026-11-13")!) }
    #expect(try s.load(DayID("2026-11-13")!).tasks.isEmpty)
    #expect(try s.load(s.today()).tasks[0].state == .done)
}
