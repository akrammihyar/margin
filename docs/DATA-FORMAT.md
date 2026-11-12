# Data format

This document is a stable contract. The app, the `margin` command, the MCP server, and
AI agents with file access all read and write these files. There is no database.

## Location

`~/Margin/` — or the folder in the environment variable `MARGIN_HOME`.

```
~/Margin/
  AGENTS.md              instructions for AI agents (written by the app)
  .agents-doc            the last AGENTS.md text that the app wrote (to detect owner edits)
  days/
    2026-11-12.md        one file per day; created when the first task is added
  notes/
    current.md           the current note
    archive/
      2026-11-12-1530-first-line-of-note.md
```

App settings (tab position, shortcut, pin state) are in the macOS user defaults
(`app.margin.Margin`), not in this folder.

## Day file

```markdown
# 2026-11-12

- [ ] Edit reel v3 @now
- [x] Send invoice @done(14:32)
- [ ] Call supplier
- [~] Old idea
- [>] Plan next week @moved(2026-11-13)
```

| Marker | State |
|---|---|
| `- [ ]` | open |
| `- [x]` | completed. `@done(HH:MM)` is the local completion time. |
| `- [~]` | archived (not completed, not shown in the app) |
| `- [>]` | moved to a different day. `@moved(YYYY-MM-DD)` is the target day. |

Rules:

1. A task line matches `^\s*[-*]\s+\[( |x|X|~|>)\]\s+(.*)$`.
2. The order of the lines is the order in the list.
3. `@now` marks the focus task. Maximum one per file. If there are more, the first one wins.
4. The tags `@now`, `@done(...)`, `@moved(...)` are read only at the end of the line, in any
   order. The same text in the middle of a line is part of the task text.
5. A task is one line. Writers change line breaks in task text to spaces.
6. All other lines (the `# date` header, blank lines, free text) are kept unchanged and in
   position when a file is written again. The app does not show them.
7. A task has no permanent ID. The command and the MCP tools name a task by its 1-based
   position among **all** task lines of that day (archived and moved lines are counted), or
   by text: an exact match (case is ignored) wins, else the text must be part of exactly one task.
8. Writers write the full file atomically (temporary file, then rename). Each operation reads
   the file again immediately before it changes it. The last writer wins.
9. Files are UTF-8. `\n` and `\r\n` line ends are accepted; `\n` is written.

## Notes

`notes/current.md` is free text. An archived note is the same text in
`notes/archive/YYYY-MM-DD-HHmm-<slug>.md`. The slug is the first non-empty line in lower
case, with each run of other characters changed to `-`, maximum 40 characters (`note` when
empty). When the name exists, `-2`, `-3`, … is added. The title of a note is its first
non-empty line.

## Compatibility

- New tags are added at the end of the line with the form `@name` or `@name(value)`.
- Readers must keep task text that they do not understand.
- A change that an older reader cannot read safely needs a new major version of Margin.
