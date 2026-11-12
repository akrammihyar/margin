import Foundation
import MarginCommands
import MarginCore

let arguments = Array(CommandLine.arguments.dropFirst())
let store = Store()
let notes = NotesStore()

if arguments.first == "mcp" {
    MCPServer(store: store, notes: notes).runStdio()
    exit(0)
}

let result = CommandRunner(store: store, notes: notes).run(arguments)
FileHandle.standardOutput.write(Data(result.stdout.utf8))
FileHandle.standardError.write(Data(result.stderr.utf8))
exit(result.exitCode)
