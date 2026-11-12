# Contributing

## Build and test

Requirements: macOS 26, and Xcode 26 or the Command Line Tools for Xcode 26.

```
scripts/test.sh          # unit tests
scripts/build-app.sh     # builds build/Margin.app
scripts/install.sh       # builds and installs /Applications/Margin.app
scripts/measure.sh       # measures resource use
```

To try the app without changing your own data, set `MARGIN_HOME` to an empty folder and
start `build/Margin.app/Contents/MacOS/Margin` from a terminal.

## Rules

- Write the test first for each change in `MarginCore` or `MarginCommands`.
- The app does not parse or write files. Add the logic to `MarginCore`.
- No third-party dependencies. No network code. No repeating timers and no polling.
- The file format is a contract. If you change it, update `docs/DATA-FORMAT.md` and
  `AgentsDoc.text` in the same commit.
- Record each design decision in `docs/DECISIONS.md` with the date and the reason.
- Update `CHANGELOG.md`.
- Commit messages: `feat: …`, `fix: …`, `docs: …`, `chore: …`.

Read `docs/ARCHITECTURE.md` before a larger change. It has a worked example of a new feature.
