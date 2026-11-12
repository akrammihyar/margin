# Margin

Margin is a small native macOS app that keeps the task list of the day at the edge of your
screen. Touch the edge tab, or press a shortcut, and the list opens. Pin it and it stays
above all your windows. Your AI agents can read and change the same list.

- **Always near.** Small pen marks on any screen edge, one for each task of today: orange is completed, grey is open. The list opens on hover, on click, or with a global shortcut.
- **Fast capture.** Shortcut, type, Enter, Esc. Your current app stays active.
- **One list for each day.** A new day starts empty. Margin shows the open tasks of the last day, and you add, archive, or delete each one.
- **Focus task.** Mark one task as "now". The tab shows its name.
- **Notes.** One current note, and an archive of saved notes.
- **Plain files.** Each day is a Markdown file in `~/Margin`. There is no database, no account, and no network connection.
- **Made for agents.** A `margin` command and an MCP server give Claude Code, Codex, and other local agents the same list.
- **Light.** Native Swift, Liquid Glass, no timers, no polling. See [Resource use](#resource-use).

## Requirements

- macOS 26 or later, Apple silicon.
- To build: Xcode 26, or only the Command Line Tools for Xcode 26
  (`xcode-select --install`). Full Xcode is not necessary.

## Install

There is no download at this time. You build Margin on your own Mac. This takes
approximately one minute.

```
git clone https://github.com/akrammihyar/margin.git
cd margin
scripts/install.sh
```

The script builds `Margin.app`, puts it in `/Applications`, and starts it. The build is
signed ad hoc for your own Mac, so macOS does not show a Gatekeeper warning.

To update: `git pull`, then `scripts/install.sh` again. Your tasks are not changed.

To remove: quit Margin, delete `/Applications/Margin.app`, and delete the link
(`rm ~/.local/bin/margin` or `/usr/local/bin/margin`). Your tasks stay in `~/Margin`
until you delete that folder.

Then open **Settings** from the menu bar icon (right-click → Settings…):

- **Start at login** — turn this on to have Margin always available.
- **Install margin command** — makes the `margin` command available in the terminal.

## Use

| To do this | Do this |
|---|---|
| Open the list | Rest the pointer on the marks at the screen edge, click them, click the menu bar icon, or press **Control + Option + M** |
| Add a task | Type in "Add a task" and press Enter |
| Complete a task | Click it |
| Edit a task | Point at it and click the pencil, or right-click → Edit |
| Change the order | Drag a task onto a different task |
| Set the focus task | Point at it and click the target icon, or right-click → Focus on This |
| Plan for tomorrow | Click `›` to go to Tomorrow and add tasks, or right-click a task → Move to Tomorrow |
| See an earlier day | Click `‹`. Earlier days are read-only in the app. |
| Keep the list on top | Click the pin. Drag the top of a pinned list to move it. |
| Move the tab | Drag it to any edge of any display |
| Hide the tab | Right-click the menu bar icon → Show Edge Tab |
| Close the list | Move the pointer away, or press Esc |
| Take a note | Click **Notes**. "New Note" saves the current note and starts a blank one. |

With the keyboard, in the task list: ↑ and ↓ select, Space completes, Return edits, Delete removes.

### The morning review

When an earlier day has open tasks, a banner shows at the top of today: "3 open from Wed 11 Nov".
Click **Review**. For each task: **Add to Today**, **Archive** (keep it in the history as not
completed), or **Delete**. **Add All** and **Archive All** do the same for all of them.

## The `margin` command

```
margin list [--date D] [--all]             tasks of a day (--all shows archived and moved tasks)
margin add "text" [--date D]
margin done <n|text> [--date D]
margin undo <n|text> [--date D]            reopen a task
margin edit <n|text> "new text" [--date D]
margin rm <n|text> [--date D]
margin move <n|text> --to D [--date D]
margin reorder <n> <new position> [--date D]
margin focus <n|text> | --clear
margin history [--from D] [--to D] [--done|--open]   default: the last 7 days
margin note show | set "text" | append "text" | new | list
margin mcp                                 start the MCP server (stdio)
margin path                                print the data folder
```

`D` is `today`, `tomorrow`, `yesterday`, or `YYYY-MM-DD`. `<n|text>` is a task number from
`margin list`, or text that matches one task. Add `--json` for JSON output.

The command works when the app is not running. When the app is running, it shows each change immediately.

## AI agents

There are three ways for an agent to use your list. All of them use the same files.

1. **Files.** An agent with file access can read `~/Margin/AGENTS.md`. That file explains the format and the commands.
2. **The command.** Any agent that can run shell commands can use `margin`.
3. **MCP.** `margin mcp` is a local MCP server with 15 tools (`list_tasks`, `add_task`, `complete_task`, `get_history`, …).

Register the MCP server (Settings → AI agents shows these lines with the correct path):

```
claude mcp add --scope user margin -- /path/to/margin mcp
codex mcp add margin -- /path/to/margin mcp
```

Then you can ask your agent: "What are my tasks for today?", "Add 'send the proposal' to
tomorrow", or "What did I complete this week?".

### Tested agents (2026-11-12)

| Agent | Result |
|---|---|
| Claude Code | Connected through MCP (`claude mcp list` shows `margin` as connected). |
| Codex (command line and desktop app) | Registered through MCP with `codex mcp add`. Both use the same Codex configuration. |
| Other local agents with shell or file access | Use the `margin` command, or point the agent at `~/Margin/AGENTS.md`. No documented local MCP setting was found for them. |

## Customize

### Without code

| What | Where |
|---|---|
| Shortcut | Settings → Shortcut: click, then press the new combination |
| Tab position | Drag the tab to any edge of any display |
| Tab on or off | Settings → Show edge tab, or right-click the menu bar icon |
| Focus task name on the tab | Settings → Show focus task on the tab |
| Completion sound | Settings → Completion sound |
| Start at login | Settings → Start at login |
| Data folder | Set the environment variable `MARGIN_HOME` |
| Instructions for agents | Edit `~/Margin/AGENTS.md`. Margin does not overwrite a file that you edited. |

### With a small code change

Each of these is a constant in one file. Change the value and run `scripts/install.sh`.

| What | File | Constant |
|---|---|---|
| Colour of the tab | `Sources/MarginApp/EdgeTabView.swift` | `TabMetrics.orange` |
| Size, tilt, and number of the pen marks | `Sources/MarginApp/EdgeTabView.swift` | `TabMetrics.markThickness`, `markLengths`, `markTilt`, `maxMarks` |
| Distance of the tab from the screen edge | `Sources/MarginApp/EdgeTabView.swift` | `TabMetrics.inset` |
| Panel width and corner radius | `Sources/MarginApp/Views/PanelView.swift` | `PanelMetrics.width`, `PanelMetrics.corner` |
| Hover delays (open 0.15 s, close 0.30 s) | `Sources/MarginApp/HoverCoordinator.swift` | `openDelay`, `closeDelay` |
| Completion sound and volume | `Sources/MarginApp/CompletionSound.swift` | the sound name (`Tink`) and `volume` |
| Default shortcut | `Sources/MarginApp/Settings.swift` | `hotKeyCode`, `hotKeyModifiers`, `hotKeyDisplay` |
| Default data folder | `Sources/MarginCore/Store.swift` | `Store.defaultRoot()` |
| App name | `Sources/MarginCore/AppInfo.swift` and `Resources/Info.plist` | `AppInfo.name` |

For a larger change, read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). It has a worked
example of a new feature.

## Data

All data is in `~/Margin` (set `MARGIN_HOME` to use a different folder). The format is in
[docs/DATA-FORMAT.md](docs/DATA-FORMAT.md). You can read, edit, back up, or sync these files
with any tool.

## Resource use

Measured on 2026-11-12 with `scripts/measure.sh` on an Apple silicon MacBook with macOS 26.3
(release build, 20 tasks today, 90 days of history, panel closed, tab visible, screen on, 5 minutes idle).

| Measure | Result | Limit |
|---|---|---|
| Idle CPU (average) | 0.000 % | 0.1 % |
| Idle wake-ups | 0.00 per second | approximately 0 |
| Memory footprint | 25 MB | 50 MB |
| Launch to ready | 152 ms | 500 ms |
| App size | 2.4 MB | 15 MB |

Run `scripts/measure.sh` to measure on your own Mac.

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how the code is organized, and how to add a feature
- [docs/DATA-FORMAT.md](docs/DATA-FORMAT.md) — the file format
- [docs/DECISIONS.md](docs/DECISIONS.md) — decisions and their reasons
- [docs/superpowers/specs/](docs/superpowers/specs/) — the product requirements and design
- [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md)

## Roadmap

Possible later: import from Notion, sync to
iPhone, due times and reminders, a signed and notarized download.

## Licence

MIT. See [LICENSE](LICENSE).
