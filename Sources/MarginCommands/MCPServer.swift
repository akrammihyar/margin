import Foundation
import MarginCore

/// A minimal MCP server: JSON-RPC 2.0, one message per line, on stdin and stdout.
public final class MCPServer {
    private let tools: MCPTools
    static let defaultProtocolVersion = "2025-06-18"

    public init(store: Store, notes: NotesStore) {
        tools = MCPTools(store: store, notes: notes)
    }

    /// Handles one message. Returns the reply line, or nil for a notification.
    public func handle(line: String) -> String? {
        guard let data = line.data(using: .utf8),
              let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return reply(id: NSNull(), error: (-32700, "Parse error"))
        }
        let id = message["id"]
        guard let method = message["method"] as? String else {
            // A response from the client, or an invalid request.
            return id == nil || message["result"] != nil || message["error"] != nil ? nil : reply(id: id!, error: (-32600, "Invalid request"))
        }
        let params = message["params"] as? [String: Any] ?? [:]
        guard let id else { return nil }  // notifications get no reply

        switch method {
        case "initialize":
            let version = (params["protocolVersion"] as? String) ?? MCPServer.defaultProtocolVersion
            return reply(id: id, result: [
                "protocolVersion": version,
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": AppInfo.cliName, "version": AppInfo.version],
                "instructions": "Margin is the owner's daily task list and notes. Use list_tasks to see today, and get_history with filter=done to summarize completed work.",
            ])
        case "ping":
            return reply(id: id, result: [String: Any]())
        case "tools/list":
            return reply(id: id, result: ["tools": MCPTools.definitions])
        case "tools/call":
            let name = (params["name"] as? String) ?? ""
            let args = params["arguments"] as? [String: Any] ?? [:]
            do {
                return reply(id: id, result: toolResult(try tools.call(name, args), isError: false))
            } catch let e as MarginError {
                return reply(id: id, result: toolResult(e.description, isError: true))
            } catch let e as MCPTools.ToolError {
                return reply(id: id, result: toolResult(e.message, isError: true))
            } catch {
                return reply(id: id, result: toolResult(error.localizedDescription, isError: true))
            }
        default:
            return reply(id: id, error: (-32601, "Method not found: \(method)"))
        }
    }

    /// Blocks and serves until stdin closes.
    public func runStdio() {
        while let line = readLine(strippingNewline: true) {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            if let out = handle(line: line) {
                FileHandle.standardOutput.write(Data((out + "\n").utf8))
            }
        }
    }

    private func toolResult(_ text: String, isError: Bool) -> [String: Any] {
        ["content": [["type": "text", "text": text]], "isError": isError]
    }

    private func reply(id: Any, result: [String: Any]) -> String {
        Formatting.jsonString(["jsonrpc": "2.0", "id": id, "result": result])
    }

    private func reply(id: Any, error: (Int, String)) -> String {
        Formatting.jsonString(["jsonrpc": "2.0", "id": id, "error": ["code": error.0, "message": error.1]])
    }
}
