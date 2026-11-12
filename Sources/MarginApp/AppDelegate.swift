import AppKit
import SwiftUI
import MarginCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var watcher: DirectoryWatcher!
    private var dayClock: DayClock!
    private var panel: PanelController!
    private var tab: EdgeTabController!
    private var hover: HoverCoordinator!
    private var statusItem: StatusItemController!
    private var settings: SettingsWindowController!
    private var hotKey: HotKey?
    private let measuring = ProcessInfo.processInfo.environment["MARGIN_MEASURE"] != nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single instance.
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
            NSApp.terminate(nil)
            return
        }

        let clock = AppDelegate.makeClock()
        let store = Store(clock: clock)
        let notes = NotesStore(clock: clock)
        try? AgentsDoc.install(root: store.root, version: AppInfo.version)

        model = AppModel(store: store, notes: notes)
        panel = PanelController(model: model)
        tab = EdgeTabController(model: model)

        hover = HoverCoordinator(
            open: { [weak self] in self?.showPanel(focusInput: false) },
            close: { [weak self] in self?.panel.hide() },
            canClose: { [weak self] in
                guard let self else { return true }
                if self.panel.isPinned || self.panel.isEditingText { return false }
                let mouse = NSEvent.mouseLocation
                return !(self.panel.isVisible && self.panel.frame.contains(mouse)) && !self.tab.tabFrame.contains(mouse)
            })

        tab.onPointer = { [weak self] inside in
            if inside { self?.hover.pointerEntered(opens: true) } else { self?.hover.pointerExited() }
        }
        tab.onClick = { [weak self] in
            self?.hover.cancel()
            self?.showPanel(focusInput: false)
        }
        tab.onDragBegan = { [weak self] in
            self?.hover.cancel()
            if self?.panel.isPinned == false { self?.panel.hide() }
        }
        panel.onPointer = { [weak self] inside in
            if inside { self?.hover.pointerEntered(opens: false) } else { self?.hover.pointerExited() }
        }
        panel.onVisibilityChange = { [weak self] visible in
            guard let self else { return }
            self.tab.setPanelOpen(visible && !self.panel.isPinned)
        }
        panel.anchorProvider = { [weak self] in self!.currentAnchor() }
        model.onStateChange = { [weak self] in self?.tab.refreshLayout(animated: true) }

        statusItem = StatusItemController(
            onTogglePanel: { [weak self] in self?.togglePanel(focusInput: false) },
            onOpenSettings: { [weak self] in self?.settings.show() },
            onToggleTab: { [weak self] in
                guard let self else { return }
                self.tab.isEnabled.toggle()
            })

        settings = SettingsWindowController(makeView: { [weak self] in
            SettingsView(
                onChange: { self?.tab.refreshLayout() },
                onShortcut: { code, modifiers, display in self?.registerHotKey(code: code, modifiers: modifiers, display: display) ?? false },
                dataFolder: store.root)
        })

        watcher = DirectoryWatcher(url: store.root) { [weak self] in self?.model.reload() }
        watcher.start()
        dayClock = DayClock(now: clock, calendar: store.calendar) { [weak self] in self?.model.dayDidChange() }

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.tab.refreshLayout()
                self?.panel.displaysChanged()
            }
        }

        _ = registerHotKey(code: Settings.hotKeyCode, modifiers: Settings.hotKeyModifiers, display: Settings.hotKeyDisplay)
        panel.restorePinned(anchor: currentAnchor())
        if measuring { print("MARGIN_READY"); fflush(stdout) }
        installDebugChannel()
    }

    /// A test channel, active only when the environment variable `MARGIN_DEBUG` is set.
    /// A script posts the distributed notification `app.margin.Margin.debug` with a command as its object.
    private func installDebugChannel() {
        guard ProcessInfo.processInfo.environment["MARGIN_DEBUG"] != nil else { return }
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.margin.Margin.debug"), object: nil, queue: .main) { [weak self] note in
            let command = note.object as? String ?? ""
            Task { @MainActor in
                guard let self else { return }
                switch command {
                case "show": self.showPanel(focusInput: false)
                case "hide": self.panel.hide()
                case "toggle": self.togglePanel(focusInput: false)
                case "shortcut": self.shortcutPressed()
                case "pin": self.panel.togglePin()
                case "hover-in": self.hover.pointerEntered(opens: true)
                case "hover-out": self.hover.pointerExited()
                case "tab-toggle": self.tab.isEnabled.toggle()
                case "notes": self.model.mode = .notes
                case "tasks": self.model.mode = .tasks
                case "settings": self.settings.show()
                default: break
                }
                let f = self.panel.frame, t = self.tab.tabFrame
                print("DEBUG \(command): panelVisible=\(self.panel.isVisible) pinned=\(self.panel.isPinned) editing=\(self.panel.isEditingText) panel=\(Int(f.minX)),\(Int(f.minY)),\(Int(f.width)),\(Int(f.height)) tab=\(Int(t.minX)),\(Int(t.minY)),\(Int(t.width)),\(Int(t.height)) edge=\(self.tab.edge.rawValue) rows=\(self.model.rows.count) focus=\(self.model.todayFocusText ?? "-") review=\(self.model.reviewRows.count) day=\(self.model.viewedDay)")
                fflush(stdout)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.flushNote()
    }

    /// The real clock, or a shifted clock for tests: `-debugNow 2026-11-12T23:59:50`.
    private static func makeClock() -> @Sendable () -> Date {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-debugNow"), i + 1 < args.count {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let start = f.date(from: args[i + 1]) {
                let offset = start.timeIntervalSinceNow
                return { Date().addingTimeInterval(offset) }
            }
        }
        return { Date() }
    }

    // MARK: Panel

    /// Where an unpinned panel attaches: the tab, or the menu bar icon when the tab is off.
    private func currentAnchor() -> PanelController.Anchor {
        if tab.isEnabled {
            return .init(rect: tab.tabFrame, edge: tab.edge, visible: tab.screen.visibleFrame)
        }
        if let a = statusItem?.anchor {
            return .init(rect: a.rect, edge: .top, visible: a.screen.visibleFrame)
        }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        return .init(rect: CGRect(x: screen.visibleFrame.maxX - 40, y: screen.visibleFrame.maxY, width: 24, height: 24), edge: .top, visible: screen.visibleFrame)
    }

    private func showPanel(focusInput: Bool) {
        panel.show(anchor: currentAnchor(), focusInput: focusInput)
    }

    private func togglePanel(focusInput: Bool) {
        hover.cancel()
        if panel.isVisible && !panel.isPinned {
            panel.hide()
        } else {
            showPanel(focusInput: focusInput)
        }
    }

    /// The global shortcut: open with the cursor in "Add a task"; press again to close.
    private func shortcutPressed() {
        hover.cancel()
        let start = CFAbsoluteTimeGetCurrent()
        if panel.isVisible && !panel.isPinned && panel.isEditingText {
            panel.hide()
            return
        }
        model.mode = .tasks
        if model.viewedDay != model.today { model.goToToday() }
        if panel.isVisible { panel.focusInput() } else { showPanel(focusInput: true) }
        if measuring {
            print(String(format: "MARGIN_HOTKEY_MS %.1f", (CFAbsoluteTimeGetCurrent() - start) * 1000)); fflush(stdout)
        }
    }

    private func registerHotKey(code: UInt32, modifiers: UInt32, display: String) -> Bool {
        let old = hotKey
        old?.unregister()
        if let new = HotKey(keyCode: code, modifiers: modifiers, handler: { [weak self] in
            Task { @MainActor in self?.shortcutPressed() }
        }) {
            hotKey = new
            Settings.hotKeyCode = code
            Settings.hotKeyModifiers = modifiers
            Settings.hotKeyDisplay = display
            return true
        }
        // Keep the previous shortcut.
        hotKey = HotKey(keyCode: Settings.hotKeyCode, modifiers: Settings.hotKeyModifiers, handler: { [weak self] in
            Task { @MainActor in self?.shortcutPressed() }
        })
        return false
    }
}
