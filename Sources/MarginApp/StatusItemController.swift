import AppKit
import MarginCore

/// The menu bar icon. Left click opens the panel. Right click shows the menu.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onTogglePanel: () -> Void
    private let onOpenSettings: () -> Void
    private let onToggleTab: () -> Void

    init(onTogglePanel: @escaping () -> Void, onOpenSettings: @escaping () -> Void, onToggleTab: @escaping () -> Void) {
        self.onTogglePanel = onTogglePanel
        self.onOpenSettings = onOpenSettings
        self.onToggleTab = onToggleTab
        super.init()
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: AppInfo.name)
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "\(AppInfo.name) — click to open, right-click for the menu"
        }
    }

    /// The frame of the icon on screen, and its screen.
    var anchor: (rect: CGRect, screen: NSScreen)? {
        guard let window = item.button?.window, let screen = window.screen else { return nil }
        return (window.frame, screen)
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            onTogglePanel()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let tab = NSMenuItem(title: "Show Edge Tab", action: #selector(toggleTab), keyEquivalent: "")
        tab.target = self
        tab.state = Settings.tabEnabled ? .on : .off
        menu.addItem(tab)
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit \(AppInfo.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func toggleTab() { onToggleTab() }
    @objc private func openSettings() { onOpenSettings() }
}
