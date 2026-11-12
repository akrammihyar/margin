import Foundation

/// The instruction file for AI agents in the data folder.
public enum AgentsDoc {
    public static func text(version: String) -> String {
        """
        # Margin — instructions for AI agents

        Written by Margin \(version). This folder holds the daily task lists and notes of the owner.
        You can read, add, edit, and complete tasks, for today and for earlier days.

        ## Folder

        ```
        days/YYYY-MM-DD.md      one file per day
        notes/current.md        the current note (free text)
        notes/archive/*.md      saved notes
        ```

        ## Day file format

        ```markdown
        # 2026-11-12

        - [ ] Edit reel v3 @now
        - [x] Send invoice @done(14:32)
        - [~] Old idea
        - [>] Plan next week @moved(2026-11-13)
        ```

        | Marker | State |
        |---|---|
        | `- [ ]` | open |
        | `- [x]` | completed; `@done(HH:MM)` is the local completion time |
        | `- [~]` | archived (not completed, hidden in the app) |
        | `- [>]` | moved to a different day; `@moved(YYYY-MM-DD)` is the target day |

        - The order of the lines is the order in the list.
        - `@now` marks the one focus task of the day.
        - Tags are at the end of the line. A task is one line.
        - Other lines are permitted and are kept, but the app does not show them.

        ## Prefer the `margin` command for changes

        The command writes safely and keeps the format correct. Add `--json` for JSON output.
        `--date` accepts `today`, `tomorrow`, `yesterday`, or `YYYY-MM-DD` (default `today`).
        `<n|text>` is the task number from `margin list`, or a text fragment that matches one task.

        ```
        margin list [--date D] [--all]
        margin add "text" [--date D]
        margin done <n|text> [--date D]
        margin undo <n|text> [--date D]
        margin edit <n|text> "new text" [--date D]
        margin rm <n|text> [--date D]
        margin move <n|text> --to D [--date D]
        margin reorder <n> <new position> [--date D]
        margin focus <n|text> | --clear
        margin history [--from D] [--to D] [--done|--open]
        margin note show | set "text" | append "text" | new | list
        margin path
        ```

        The same operations are available as MCP tools from `margin mcp`.

        ## Summaries

        - "What did I complete this week?" → `margin history --done` (default: the last 7 days).
        - A specific range → `margin history --done --from 2026-11-01 --to 2026-11-07`.
        - "What is still open?" → `margin history --open`.

        ## Rules

        - Do not delete tasks unless the owner asks. To hide a task, the owner archives it in the app.
        - If you edit a file directly, write the full file and keep the lines that you do not change.
        - The app shows your changes immediately.

        """
    }

    /// Writes `AGENTS.md` if it does not exist. Replaces it only if the owner did not edit
    /// the text that Margin wrote last (recorded in `.agents-doc`).
    public static func install(root: URL, version: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let doc = root.appendingPathComponent("AGENTS.md")
        let record = root.appendingPathComponent(".agents-doc")
        let new = text(version: version)
        if fm.fileExists(atPath: doc.path) {
            let existing = try String(contentsOf: doc, encoding: .utf8)
            let recorded = try? String(contentsOf: record, encoding: .utf8)
            guard existing == recorded, existing != new else { return }
        }
        try Data(new.utf8).write(to: doc, options: .atomic)
        try Data(new.utf8).write(to: record, options: .atomic)
    }
}
