# Decisions

A dated list of decisions that are not in the design document, each with its reason.

| Date | Decision | Reason |
|---|---|---|
| 2026-11-12 | Tests use Swift Testing through `scripts/test.sh`. | With Command Line Tools only, `swift test` does not find `Testing.framework`. The script adds the framework search path when Xcode is not installed. |
| 2026-11-12 | Swift tools version 6.2, language mode 5. | Tools 6.2 is necessary for the macOS 26 platform value. Language mode 5 keeps AppKit callback code simple; strict concurrency can be adopted later. |
| 2026-11-12 | A fourth target `MarginCommands` holds the CLI and MCP logic. | The logic can be tested as a library; the `margin` executable is a thin `main`. |
