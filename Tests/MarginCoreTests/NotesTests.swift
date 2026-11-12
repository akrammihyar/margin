import Foundation
import Testing
@testable import MarginCore

@Test func newNoteArchivesAndClears() throws {
    let n = makeNotes(now: "2026-11-12T15:30"); try n.setCurrent("Video ideas!\nline 2")
    let a = try n.newNote()
    #expect(a?.url.lastPathComponent == "2026-11-12-1530-video-ideas.md"); #expect(a?.title == "Video ideas!")
    #expect(try n.current() == ""); #expect(try n.newNote() == nil)
    #expect(try n.list().count == 1)
}
@Test func sameNameGetsSuffix() throws {
    let n = makeNotes(now: "2026-11-12T15:30"); try n.setCurrent("x"); try n.newNote(); try n.setCurrent("x")
    #expect(try n.newNote()?.url.lastPathComponent == "2026-11-12-1530-x-2.md")
}
@Test func openSwapsCurrent() throws {
    let n = makeNotes(now: "2026-11-12T15:30"); try n.setCurrent("first"); let a = try n.newNote()!
    try n.setCurrent("second"); try n.open(a)
    #expect(try n.current() == "first"); #expect(try n.list().map(\.title) == ["second"])
}
@Test func appendAndDelete() throws {
    let n = makeNotes(); try n.append("a"); try n.append("b"); #expect(try n.current() == "a\nb")
    try n.deleteCurrent(); #expect(try n.current() == "")
}
@Test func agentsDocNotOverwrittenWhenEdited() throws {
    let root = tempRoot(); try AgentsDoc.install(root: root, version: "1.0.0")
    let url = root.appendingPathComponent("AGENTS.md"); #expect(try String(contentsOf: url, encoding: .utf8).contains("margin add"))
    try AgentsDoc.install(root: root, version: "1.1.0"); #expect(try String(contentsOf: url, encoding: .utf8) == AgentsDoc.text(version: "1.1.0"))
    try "mine".write(to: url, atomically: true, encoding: .utf8)
    try AgentsDoc.install(root: root, version: "1.2.0"); #expect(try String(contentsOf: url, encoding: .utf8) == "mine")
}
