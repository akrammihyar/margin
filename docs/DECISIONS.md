# Decisions

A dated list of decisions that are not in the design document, each with its reason.

| Date | Decision | Reason |
|---|---|---|
| 2026-11-12 | Tests use Swift Testing through `scripts/test.sh`. | With Command Line Tools only, `swift test` does not find `Testing.framework`. The script adds the framework search path when Xcode is not installed. |
| 2026-11-12 | Swift tools version 6.2, language mode 5. | Tools 6.2 is necessary for the macOS 26 platform value. Language mode 5 keeps AppKit callback code simple; strict concurrency can be adopted later. |
| 2026-11-12 | A click on a task completes it at once. Edit is by the pencil button, the context menu, or Return. There is no double-click to edit. | A double-click gesture makes each single click wait. This replaces "double-click to edit" in the design document. |
| 2026-11-12 | The default display of the tab is the primary display. | `NSScreen.main` follows the keyboard focus and put the tab on an external display. |
| 2026-11-12 | The tab stays in view while the panel is open; the panel opens next to it. | A tab that hides cannot be dragged or clicked. This replaces the mockup where the tab fades. |
| 2026-11-12 | `DayClock` sets one one-shot deadline at the next midnight, and also listens for system notifications. | Robust after sleep, and testable with `-debugNow`. Cost: one wake per day. |
| 2026-11-12 | The open and close animation is a SwiftUI spring on the panel content. | `NSWindow.animator().setFrame` did not move the borderless panel. |
| 2026-11-12 | `Calendar.autoupdatingCurrent` is the default calendar of the stores. | `Calendar.current` is a snapshot; the app runs for weeks and must follow a time zone change. |
| 2026-11-12 | Only open tasks can move to a different day. | A move of a completed task would make an open copy and lose the completed state. |
| 2026-11-12 | The MCP `task` argument has the type string ("2" or text). | A union type in the tool schema is not accepted by all clients. |
| 2026-11-12 | The app has a hidden main menu with an Edit menu. | AppKit sends copy, paste, and undo through menu items, also in an accessory app. |
| 2026-11-12 | Known limits of 1.0: no file lock for parallel writers (last writer wins); text that ends with `@now` is read as a tag; an indented task line loses its indentation; a click on a row does not select it for the keyboard. | Small, and recorded for a later version. |
| 2026-11-12 | The edge tab is a floating capsule with an orange outline, 5 pt from the edge (owner decision, design C). | The glass tab was dark and translucent, and the owner could not find it. The window still touches the edge, so the pointer at the edge opens the list. |
| 2026-11-12 | A fourth target `MarginCommands` holds the CLI and MCP logic. | The logic can be tested as a library; the `margin` executable is a thin `main`. |
