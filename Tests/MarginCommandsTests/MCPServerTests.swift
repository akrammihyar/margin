import Foundation
import Testing
@testable import MarginCommands
@testable import MarginCore

func makeServer() -> MCPServer { let (s, n) = makeStores(); return MCPServer(store: s, notes: n) }
func json(_ s: String) throws -> [String: Any] { try JSONSerialization.jsonObject(with: Data(s.utf8)) as! [String: Any] }

@Test func initializeAndList() throws {
    let s = makeServer()
    let r = try json(s.handle(line: #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}"#)!)
    #expect((r["result"] as! [String: Any])["protocolVersion"] as? String == "2025-03-26")
    #expect(s.handle(line: #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#) == nil)
    let l = try json(s.handle(line: #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#)!)
    let names = ((l["result"] as! [String: Any])["tools"] as! [[String: Any]]).map { $0["name"] as! String }
    #expect(Set(names) == ["list_tasks","add_task","complete_task","reopen_task","edit_task","delete_task","move_task","reorder_task","set_focus","get_history","get_note","set_note","append_note","new_note","list_notes"])
}
@Test func callAddThenComplete() throws {
    let s = makeServer()
    _ = s.handle(line: #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"add_task","arguments":{"text":"Call supplier"}}}"#)
    let r = try json(s.handle(line: #"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"complete_task","arguments":{"task":1}}}"#)!)
    let res = r["result"] as! [String: Any]; #expect(res["isError"] as? Bool == false)
    let text = ((res["content"] as! [[String: Any]])[0]["text"] as! String)
    #expect(text.contains(#""state":"done""#))
}
@Test func mcpErrors() throws {
    let s = makeServer()
    #expect((try json(s.handle(line: "not json")!)["error"] as! [String: Any])["code"] as? Int == -32700)
    #expect((try json(s.handle(line: #"{"jsonrpc":"2.0","id":3,"method":"nope"}"#)!)["error"] as! [String: Any])["code"] as? Int == -32601)
    let r = try json(s.handle(line: #"{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"complete_task","arguments":{"task":99}}}"#)!)
    #expect((r["result"] as! [String: Any])["isError"] as? Bool == true)
}
@Test func everyToolRuns() throws {
    let s = makeServer()
    func call(_ name: String, _ args: String) throws -> (Bool, String) {
        let r = try json(s.handle(line: #"{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"\#(name)","arguments":\#(args)}}"#)!)
        let res = r["result"] as! [String: Any]
        return (res["isError"] as! Bool, (res["content"] as! [[String: Any]])[0]["text"] as! String)
    }
    #expect(try call("add_task", #"{"text":"a"}"#).0 == false)
    #expect(try call("add_task", #"{"text":"b","date":"tomorrow"}"#).0 == false)
    #expect(try call("add_task", #"{"text":"c"}"#).0 == false)
    #expect(try call("edit_task", #"{"task":"a","text":"A"}"#).1.contains(#""text":"A""#))
    #expect(try call("set_focus", #"{"task":1}"#).1.contains(#""focus":true"#))
    #expect(try call("set_focus", "{}").1.contains(#""focus":true"#) == false)
    #expect(try call("reorder_task", #"{"task":2,"position":1}"#).0 == false)
    #expect(try call("complete_task", #"{"task":"c"}"#).0 == false)
    #expect(try call("reopen_task", #"{"task":"c"}"#).1.contains(#""state":"open""#))
    #expect(try call("move_task", #"{"task":"c","to":"tomorrow"}"#).0 == false)
    #expect(try call("delete_task", #"{"task":"A"}"#).0 == false)
    #expect(try call("list_tasks", #"{"date":"tomorrow"}"#).1.contains(#""text":"c""#))
    #expect(try call("get_history", #"{"from":"2026-11-12","to":"2026-11-13","filter":"open"}"#).1.contains("2026-11-13"))
    #expect(try call("set_note", #"{"text":"n1"}"#).0 == false)
    #expect(try call("append_note", #"{"text":"n2"}"#).1.contains(#"n1\nn2"#))
    #expect(try call("get_note", "{}").1.contains("n1"))
    #expect(try call("new_note", "{}").0 == false)
    #expect(try call("list_notes", "{}").1.contains("n1"))
    #expect(try call("no_such_tool", "{}").0 == true)
    #expect(try call("add_task", "{}").0 == true)
}
