import Foundation
import Testing
@testable import MarginCore

@Test func appInfo() { #expect(AppInfo.name == "Margin") }

@Test func dayIDRoundTrip() {
    #expect(DayID("2026-11-12")?.description == "2026-11-12")
    #expect(DayID("2026-02-30") == nil); #expect(DayID("12-11-2026") == nil); #expect(DayID("") == nil)
}
@Test func dayIDAddingCrossesMonthAndYear() {
    let c = Calendar(identifier: .gregorian)
    #expect(DayID("2026-12-31")!.adding(days: 1, calendar: c).description == "2027-01-01")
    #expect(DayID("2026-03-01")!.adding(days: -1, calendar: c).description == "2026-02-28")
}
@Test func parseSpecExample() {
    let text = "# 2026-11-12\n\n- [ ] Edit reel v3 @now\n- [x] Send invoice @done(14:32)\n- [ ] Call supplier\n- [~] Old idea\n- [>] Plan next week @moved(2026-11-13)\n"
    let f = DayFile.parse(text, day: DayID("2026-11-12")!)
    #expect(f.tasks.map(\.text) == ["Edit reel v3","Send invoice","Call supplier","Old idea","Plan next week"])
    #expect(f.tasks.map(\.state) == [.open,.done,.open,.archived,.moved])
    #expect(f.tasks[0].isFocus); #expect(f.tasks[1].doneAt == "14:32")
    #expect(f.tasks[4].movedTo == DayID("2026-11-13"))
    #expect(f.render() == text)
}
@Test func tolerantInputKeepsUnknownLines() {
    let text = "notes from agent\n* [X] Big  one\n\n  - [ ] indented @now\nfree text\n- [ ] second @now\n"
    let f = DayFile.parse(text, day: DayID("2026-11-12")!)
    #expect(f.tasks.count == 3); #expect(f.tasks[0].state == .done); #expect(f.tasks[0].doneAt == nil)
    #expect(f.tasks[1].isFocus); #expect(!f.tasks[2].isFocus)
    let again = DayFile.parse(f.render(), day: f.day)
    #expect(again == f)
    #expect(f.render().contains("notes from agent\n")); #expect(f.render().contains("\nfree text\n"))
}
@Test func tagsOnlyAtEnd() {
    let f = DayFile.parse("- [ ] email @now the [ ] report @done(09:00) today\n", day: DayID("2026-11-12")!)
    #expect(f.tasks[0].text == "email @now the [ ] report @done(09:00) today"); #expect(!f.tasks[0].isFocus)
}
@Test func unicodeRoundTrip() {
    let f = DayFile.parse("- [ ] اتصل بالمورد 📞\n", day: DayID("2026-11-12")!)
    #expect(f.tasks[0].text == "اتصل بالمورد 📞"); #expect(f.render() == "- [ ] اتصل بالمورد 📞\n")
}
@Test func emptyAndCRLF() {
    #expect(DayFile.parse("", day: DayID("2026-11-12")!).tasks.isEmpty)
    #expect(DayFile.parse("- [ ] a\r\n- [x] b\r\n", day: DayID("2026-11-12")!).tasks.map(\.text) == ["a","b"])
}
