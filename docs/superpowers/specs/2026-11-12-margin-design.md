# Margin — Product Requirements and Design

- **Date:** 2026-11-12
- **Status:** Approved by the owner on 2026-11-12
- **Version in scope:** 1.0

In this document, **"Owner decision"** marks what the owner said. **"Builder call"** marks a
decision that the designer made and that the owner can change.

---

## 1. Intent

The owner writes daily tasks on paper, in Notion, or in a notes app. None of these stay
visible on the screen during work. Tasks get lost, and adding a task interrupts the work.

Margin is a small native macOS app that keeps the task list of the day at the edge of the
screen. It opens when the pointer touches it or when the owner presses a shortcut. It can be
pinned above all windows. Local AI agents can read and change the same data.

**Why an app and not a macOS widget:** a WidgetKit widget cannot open on hover, cannot float
above other windows, and cannot take quick text input. A background app with floating panels
can. (Builder call.)

## 2. Goals

1. Add a task in less than 3 seconds: shortcut, type, Enter, Esc.
2. The list is always one pointer movement or one shortcut away, in every app and Space.
3. The list can be pinned and then stays above all other windows.
4. Each day has its own list. History is kept.
5. Local AI agents can read, add, edit, and complete tasks, for today and for the history.
6. Very low resource use (see Section 9). This is an acceptance criterion.
7. The interface looks like an Apple-made app.
8. The project is documented and ready to publish as open source.

## 3. Non-goals for version 1

- Cloud sync, accounts, iPhone app.
- Import from Notion or other tools.
- A task count on the edge tab.
- Due times, reminders, notifications, recurring tasks, subtasks, tags, projects.
- Rich text in notes.
- Distribution through the Mac App Store, notarization, auto-update.

## 4. Anti-goals

Margin has failed, even if it works, when:

- it uses CPU or wakes the processor while idle,
- it is built on Electron or a web view,
- it opens by accident and covers the work of the owner,
- the data is in a format that only Margin can read,
- it sends any data off the Mac.

## 5. User experience

### 5.1 Surfaces

| Surface | Purpose |
|---|---|
| **Edge tab** | A thin tab on a screen edge. Primary way to open the panel. |
| **Panel** | The list itself: Tasks or Notes. Opens from the tab, the shortcut, or the menu bar. |
| **Menu bar icon** | Opens the panel (left click). Menu (right click): show/hide edge tab, settings, start at login, quit. |
| **Settings window** | Shortcut, edge tab on/off, tab shows focus task name on/off, sound on/off, start at login, data folder location (display and "open in Finder"), agent setup. |

The app has no Dock icon and no main window. (Builder call.)

### 5.2 Edge tab

- Owner decision: the tab can be on the left, right, top, or bottom edge, at any position
  along the edge. The owner drags it. It attaches to the nearest edge. The app remembers the
  position.
- Owner decision: the menu bar icon can disable and enable the tab.
- Builder call: the panel opens after the pointer rests on the tab for approximately 150 ms.
  A click on the tab opens it immediately.
- Builder call: the panel closes when the pointer leaves the panel and the tab for
  approximately 300 ms, unless it is pinned or a text field in it is being edited.
- Builder call: with more than one display, the tab stays on the display where the owner put
  it. If that display is disconnected, the tab moves to the main display at the same edge.
- Builder call: the tab is visible in all Spaces and above full-screen apps.
- **Focus task on the tab:** when a focus task exists, the tab grows into a small pill that
  shows the task name (maximum approximately 24 characters, then an ellipsis). On the left and
  right edges the text is rotated 90 degrees. A setting hides the name; then the tab shows
  only a small accent dot. (Builder call on the details; owner decision that the tab shows it.)

### 5.3 Panel

Layout from top to bottom:

1. Header: segmented control **Tasks | Notes**, and a **pin** button.
2. Tasks view:
   - Day navigator: `‹  Today · Thu 12 Nov  ›`. The owner can go to Tomorrow and to earlier
     days. A click on the title returns to Today.
   - Review banner (only when needed, see 5.5).
   - Task rows: checkbox circle, text, and a "now" badge on the focus task.
   - "Add a task" field at the bottom. Enter adds the task and keeps the field active for
     the next task.
3. Notes view: see 5.7.

Task interactions:

| Action | How |
|---|---|
| Complete / reopen | Click the checkbox or the row. Strike-through animation and soft sound. |
| Edit text | Double-click the text. Enter saves, Esc cancels. |
| Change order | Drag the row. (Owner decision.) |
| Set / clear focus | Context menu "Focus on this", or a hover button on the row. Maximum one focus task per day. Completing the focus task clears the focus. |
| Move to tomorrow | Context menu. |
| Delete | Context menu, or select and press Delete. |

Builder call: completed tasks stay in their position (they do not move to the bottom).
Builder call: earlier days are read-only in the panel. Agents and the CLI can still edit them.
Builder call: panel width approximately 300 pt; height fits the content up to approximately
70% of the screen height, then the list scrolls.

### 5.4 Shortcut and pin

- Owner decision: a global keyboard shortcut opens the panel.
- Builder call: default shortcut **Control + Option + M**, changeable in Settings. The shortcut
  opens the panel with the text cursor in "Add a task". Pressing it again, or Esc, closes
  the panel (if not pinned).
- Owner decision: when pinned, the panel stays above all windows and apps and does not hide.
- Builder call: a pinned panel also shows in all Spaces and above full-screen apps. The owner
  can drag it to any position. The app remembers the pinned state and position after restart.
  Unpin returns the panel to the tab.

### 5.5 Days

- Owner decision: each day has its own list.
- Owner decision: a new day starts empty, with an option to see the open tasks of yesterday.
  For each task the owner selects: add to today, archive, or delete.
- Builder calls:
  - The "new day" starts at local midnight. The app changes day on the system day-change
    notification and on wake from sleep. It does not poll.
  - The review banner shows the open tasks of **the most recent earlier day that has open
    tasks**, not only the calendar day before. Text: "3 open from Fri 6 Nov — Review".
  - The banner opens an inline list. Each row has: **Add to today**, **Archive**, **Delete**.
    There are also **Add all** and **Archive all**.
  - The banner goes away when that day has no open tasks. If a still earlier day has open
    tasks, the banner then shows that day.
  - Tasks that the owner planned for tomorrow are already in the list when that day starts.
    Thus a day is "empty" except for tasks planned for it.
- Meaning of the three actions:
  - **Add to today:** the task goes to the end of today. In the old day it is marked "moved".
  - **Archive:** the task stays in the old day, marked "archived" (not completed).
  - **Delete:** the task line is removed.

### 5.6 Tasks for tomorrow

Owner decision: the owner can add a task to tomorrow. Builder call: this is done by going to
Tomorrow in the day navigator and adding there, or by "Move to tomorrow" on a task of today.

### 5.7 Notes

- Owner decision: a switch between Tasks and Notes. Notes do not reset each day. One current
  note stays until the owner deletes it. "New note" saves the old note in a folder and opens
  a blank note.
- Builder calls:
  - The note is plain text (Markdown is permitted but is not rendered).
  - The note saves automatically approximately 1 second after the last key press, and when
    the panel closes.
  - The Notes view has three controls: **New note**, **All notes**, **Delete**.
  - **All notes** lists the saved notes (title = first line, and date). The owner can open a
    saved note (it becomes the current note; the previous current note is saved), or delete it.
  - "New note" on an empty current note does nothing.
  - Delete asks for confirmation.

### 5.8 Look and motion

- Owner decision: glass look. The interface must look as if Apple designed it and must follow
  the Apple design system.
- Builder calls:
  - System materials for the panel and tab background, San Francisco system font, SF Symbols,
    system accent colour, automatic light and dark mode.
  - Standard spring animations for panel open/close and for the strike-through
    (approximately 0.3 s). With "Reduce motion" on, use fades only.
  - On macOS 26 with the macOS 26 SDK, use the Liquid Glass material. With an older SDK, use
    the classic vibrancy material. See Section 8.3.
  - Completion sound: one short, soft sound (system sound or a bundled original sound).
    Setting to turn it off. (Owner decision that the sound exists.)
  - Full VoiceOver labels and keyboard navigation in the panel (arrow keys, Space to
    complete, Enter to edit).

## 6. Data

### 6.1 Principle

Plain Markdown files are the single source of data. The app, the CLI, the MCP server, and
agents with file access all read and write the same files. There is no database. (Builder
call, approved by the owner.)

### 6.2 Location

Builder call: `~/Margin/`. Reason: the Documents and Desktop folders are protected by macOS
privacy prompts and can be synced to iCloud; a folder in the home directory is not. The
location can be changed with the environment variable `MARGIN_HOME` (for tests) and is
shown in Settings.

```
~/Margin/
  AGENTS.md              instructions for AI agents (written by the app, see 7.4)
  days/
    2026-11-12.md        one file per day; created when the first task is added
  notes/
    current.md           the current note
    archive/
      2026-11-12-1530-first-line-of-note.md
```

App settings (tab position, shortcut, pin state) are in the standard macOS user defaults,
not in this folder.

### 6.3 Day file format

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
| `- [~]` | archived (not completed, out of view) |
| `- [>]` | moved to a different day. `@moved(YYYY-MM-DD)` is the target day. |

Rules:

- The order of lines is the order in the list.
- `@now` marks the focus task. Maximum one per file. If more than one is found, the first wins.
- The tags `@now`, `@done(...)`, `@moved(...)` are at the end of the line. All other text is
  the task text. Task text is one line.
- The parser is tolerant: it accepts `*` or `-`, `[X]`, missing tags, and blank lines. Lines
  that are not task lines (free text that an agent or the owner wrote) are kept unchanged
  and in position when the file is written again. The panel does not show them.
- A task has no permanent ID. The CLI and MCP address a task by its **1-based position among
  the task lines of that day**, or by a unique text fragment.
- All writers write atomically (write a temporary file, then rename). The last writer wins.
  The app reads the file again after each change on disk.

### 6.4 Notes format

`current.md` is free text. An archived note is the same text in
`notes/archive/YYYY-MM-DD-HHmm-<slug of first line>.md`.

## 7. Agent access

Owner decision: agents (Codex, Claude Code, ChatGPT, Grok; all local) can read, write, and
edit tasks, current and history. The designer selects the method.

### 7.1 Direct files

Any agent with file access can read and edit `~/Margin/`. No setup.

### 7.2 Command-line tool `margin`

One binary. It works when the app is not running. Default output is readable text; `--json`
gives JSON. `--date` accepts `today`, `tomorrow`, `yesterday`, or `YYYY-MM-DD` (default
`today`).

```
margin list [--date D] [--all]          tasks of a day (--all includes archived and moved)
margin add "text" [--date D]
margin done <n|text> [--date D]
margin undo <n|text> [--date D]         reopen
margin edit <n|text> "new text" [--date D]
margin rm <n|text> [--date D]
margin move <n|text> --to D [--date D]
margin reorder <n> <new position> [--date D]
margin focus <n|text> | --clear
margin history [--from D] [--to D] [--done|--open]   default: last 7 days
margin note show | set "text" | append "text" | new | list
margin mcp                               start the MCP server (stdio)
margin path                              print the data folder
```

### 7.3 MCP server

`margin mcp` is a local stdio MCP server with tools that match the CLI commands:
`list_tasks`, `add_task`, `complete_task`, `reopen_task`, `edit_task`, `delete_task`,
`move_task`, `reorder_task`, `set_focus`, `get_history`, `get_note`, `set_note`,
`append_note`, `new_note`, `list_notes`.

Setup in version 1:

- Claude Code and Codex: the builder registers the server and confirms that it works.
- Settings has an "Agent setup" section that shows the commands to register the server, and
  a button to install the `margin` command in the shell path.
- ChatGPT desktop and Grok: the builder examines if each one can use a local MCP server or
  local files on this Mac, connects it if possible, and reports the result. This is not a
  release blocker.

### 7.4 AGENTS.md

The app writes `~/Margin/AGENTS.md` on first launch (and updates it when the app version
changes, if the owner did not edit it). It explains the folder, the file format, the CLI
commands, and how to make a summary ("What did I complete this week?" → `margin history
--done`).

### 7.5 Daily summary by the agent

Owner decision: in scope. No app UI is necessary. `margin history` and the `get_history`
tool supply the data, and AGENTS.md tells the agent how to use them.

## 8. Technical design

### 8.1 Decisions (builder calls)

- Native Swift. SwiftUI for views, AppKit for windows (floating non-activating panels,
  status item, tracking areas).
- Zero third-party dependencies.
- Minimum system: macOS 26 (see Section 11). Target machine: Apple silicon, macOS 26.3.
- Swift Package with three targets:
  - `MarginCore` — library: file format parser and writer, store, day logic, notes. No UI.
  - `margin` — CLI and MCP server. Uses `MarginCore`.
  - `MarginApp` — the app. Uses `MarginCore`.
- The app bundle (`Margin.app`) is assembled by a script from the SwiftPM build output
  (Info.plist with `LSUIElement`, icon, ad-hoc code signature). Full Xcode is not necessary.
- Install: `Margin.app` in `/Applications`; the `margin` binary is inside the bundle and is
  linked into the shell path.
- File changes: one file-system event stream on `~/Margin/`. No polling.
- Global shortcut: Carbon hot-key API (no Accessibility permission necessary).
- Hover: tracking areas on the tab and panel. No global mouse monitoring.
- Start at login: `SMAppService`.
- The app is a single instance.

### 8.2 Left to the builder

- Internal structure of each target, names of types.
- Exact animation curves, sizes, and spacing, inside the Apple design guidelines.
- Selection of the completion sound.
- The test method. `MarginCore` must have automated tests for: the parser (including
  tolerant input and round-trip of unknown lines), all task operations, the day-change and
  review logic, and notes archive. If XCTest is not available with the installed tools, use
  a small test executable.

### 8.3 Build environment (found on the target Mac on 2026-11-12)

- macOS 26.3, arm64.
- Only Command Line Tools are installed, with Swift 5.8.1 and the macOS 13.3 SDK. Full Xcode
  is not installed. Free disk space: approximately 15 GB.
- Result: version 1 can be built now with SwiftPM, but the macOS 13 SDK does not have the
  Liquid Glass API. **Open question for the owner — see Section 11.**

## 9. Acceptance criteria

Measured on the target Mac, with a release build, 20 tasks in today, 90 day files in history.

| # | Criterion | How it is measured |
|---|---|---|
| A1 | Idle CPU ≤ 0.1% average for 5 minutes (panel closed, tab visible) | `top` / Activity Monitor sample |
| A2 | No timers and no polling when idle; idle wake-ups ≈ 0 per second | code review and `powermetrics` or Activity Monitor "Idle Wake Ups" |
| A3 | Memory footprint ≤ 50 MB after 1 hour of use | `footprint` or Activity Monitor |
| A4 | Cold launch to visible tab ≤ 0.5 s | timed |
| A5 | Shortcut to typing in the field ≤ 150 ms | perceived as immediate; timed log |
| A6 | App bundle size ≤ 15 MB | `du` |
| A7 | A task added with the CLI shows in an open panel in ≤ 1 s | manual test |
| A8 | Pinned panel stays above a full-screen app and in each Space | manual test |
| A9 | Tab can be put on each of the four edges and the position survives restart | manual test |
| A10 | Day change at midnight and after wake shows a new list and the review banner | test with injected clock, and manual |
| A11 | A file edited by hand with free text and bad spacing does not lose data after the app writes it | automated test |
| A12 | Claude Code and Codex can list, add, complete, and edit tasks through MCP | manual test |
| A13 | No network connections made by the app or CLI | code review; no network entitlement or API use |
| A14 | All `MarginCore` tests pass | test run |

## 10. Documentation and open source

Owner decision: document everything so that later changes build on it; the owner plans to
publish the project on GitHub later.

Repository contents (builder call):

- `README.md` — what it is, screenshots, install, use, shortcut, agent setup.
- `docs/superpowers/specs/` — this document and later design documents.
- `docs/ARCHITECTURE.md` — targets, data flow, window model, how to add a feature.
- `docs/DATA-FORMAT.md` — the file format as a stable contract.
- `docs/DECISIONS.md` — a dated list of decisions and the reason for each.
- `CONTRIBUTING.md`, `CHANGELOG.md`.
- `LICENSE` — MIT (builder call; the owner can select a different licence before publishing).
- No personal data, names, or absolute user paths in the repository.
- Before publishing: examine if the name "Margin" is free (GitHub, trademarks). The name is
  kept in one constant per target so that it is easy to change.
- Publishing to GitHub is done only when the owner asks.

## 11. Resolved questions

1. **Build tools (owner decision, 2026-11-12):** update the Apple Command Line Tools to
   version 26.6 (download approximately 0.9 GB) before the build. Do not install full Xcode.
   Version 1 uses the true Liquid Glass material.
2. **Minimum system (builder call, follows from 1):** macOS 26. This replaces "macOS 13" in
   Section 8.1. Older systems cannot be tested on the target Mac. The classic-material
   fallback in Section 5.8 is not built in version 1.

## 12. Decision authority

Owner statement, 2026-11-12: the builder owns the project and the code and can make
decisions when it makes sense. Rule for the builder: make technical and detail decisions
without asking, and record each one with its reason in `docs/DECISIONS.md`. Ask the owner
only when a decision changes what the owner sees or does in a way that this document does
not cover, or when an action is destructive or public (for example, publishing to GitHub).
