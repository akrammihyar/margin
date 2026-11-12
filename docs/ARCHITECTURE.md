# Architecture

## Targets

| Target | Type | Content | Rule |
|---|---|---|---|
| `MarginCore` | library | File format (`DayFile`), `Store`, review and history, `NotesStore`, `AgentsDoc`, `EdgeGeometry` | No UI. No AppKit. All logic that can be tested is here. |
| `MarginCommands` | library | `CommandRunner` (the CLI), `MCPServer` and `MCPTools` | Text in, text out. Uses only `MarginCore`. |
| `margin` | executable | `main.swift` | A thin `main` over `MarginCommands`. |
| `MarginApp` | executable | The AppKit and SwiftUI app | Never parses or writes files itself. It calls `Store` and `NotesStore`. |

There are no third-party dependencies and no network code.

## Data flow

```
owner action ─► AppModel ─► Store / NotesStore ─► files in ~/Margin
                                                        │
agent ─► margin CLI / MCP ─► Store / NotesStore ────────┤
                                                        ▼
SwiftUI views ◄─ AppModel.reload() ◄─ DirectoryWatcher (FSEvents)
```

- Every action goes to the store, and then `AppModel.reload()` reads the files again.
  The app keeps no second copy of the truth.
- `DirectoryWatcher` is one FSEvents stream on the data folder. A change by an agent
  reaches the open panel through the same `reload()`.
- Text that the owner is typing (`addDraft`, an inline edit, the note draft) is separate
  state, so a reload cannot remove it.
- A row in the panel holds a task number from the last reload. Before each action,
  `AppModel.currentRef` compares the row with the file as it is now, because a different
  process can have changed it.

## Windows

| Window | Class | Notes |
|---|---|---|
| Edge tab | `FloatingPanel` + `TabEventView` | Borderless, cannot become key. `TabEventView` handles hover, click, and drag. `EdgeTabView` draws one pen mark for each task of today (`AppModel.todayMarks`); `TabMetrics` holds its sizes and colours. |
| Panel | `FloatingPanel` + `TrackingHostingView` | Borderless, non-activating, can become key for typing. The SwiftUI content has 20 pt of transparent space around the glass. |
| Settings | `NSWindow` | A normal window. The app activates only for this window. |

Both floating windows use level `.statusBar` and the collection behaviours
`canJoinAllSpaces`, `fullScreenAuxiliary`, `stationary`, so they show in all Spaces and
above full-screen apps. The app is an accessory app (`LSUIElement`): no Dock icon.

### Position

`EdgeGeometry` (pure, tested) computes all frames:
`snap` (a point → edge and position), `tabFrame`, `panelFrame`, `clamp`.
`TabPlacement` (edge, fraction along the edge, display ID) is saved in the user defaults.
The tab uses the `visibleFrame` of its display, so it stays clear of the menu bar and the Dock.

### Hover

`HoverCoordinator` is a small state machine with two one-shot delays:

- pointer enters the tab → open after 0.15 s
- pointer leaves the tab or the panel → close after 0.30 s, if `canClose` is true
- `canClose` is false when the panel is pinned, when a text field in the panel has the
  keyboard, or when the pointer is in the panel or tab frame
- while a menu or a drag is in progress (run loop mode `eventTracking`), the close is
  scheduled again

While the panel is open, the tab is transparent and ignores the mouse. The transparent
space around the panel covers the tab area, so the pointer does not "leave" on the way
from the tab to the panel.

### No idle work

There are no repeating timers and no polling. The app wakes only for: mouse events on its
own windows, the hot key (Carbon `RegisterEventHotKey`), FSEvents, system notifications
(day change, wake, clock change, display change), and one one-shot deadline at the next
midnight (`DayClock`).

## How to add a feature

Example: a new task tag `@due(HH:MM)`.

1. **Test first.** Add parser and render tests in `Tests/MarginCoreTests/DayFileTests.swift`.
2. **Format.** Add the field to `TaskItem`, read the tag in `DayFile.parseTaskLine`, write it in `DayFile.render`.
3. **Operation.** Add a `Store` method (for example `setDue`), with tests in `StoreTests.swift`.
4. **CLI.** Add the flag or command in `CommandRunner`, the usage text, and a test.
5. **MCP.** Add the tool or argument in `MCPTools.definitions` and `MCPTools.call`, and a test.
6. **App.** Add an `AppModel` action that calls the store through `perform`, then the row UI.
7. **Documents.** Update `docs/DATA-FORMAT.md`, `AgentsDoc.text`, `README.md`, `CHANGELOG.md`,
   and add a line to `docs/DECISIONS.md` if you made a decision.

## Testing

- `scripts/test.sh` runs the unit tests (Swift Testing).
- The app has a test channel for scripts. Start the app binary with the environment variable
  `MARGIN_DEBUG=1`; then the distributed notification `app.margin.Margin.debug` with an
  object of `show`, `hide`, `toggle`, `shortcut`, `pin`, `hover-in`, `hover-out`,
  `tab-toggle`, `notes`, `tasks`, `settings`, or `dump` runs that command and prints the
  window state to stdout. The channel does not exist without the variable.
- `-debugNow 2026-11-12T23:59:50` as a launch argument shifts the clock of the app, to test
  the day change.
- `scripts/measure.sh` measures CPU, wake-ups, memory, launch time, and size.
