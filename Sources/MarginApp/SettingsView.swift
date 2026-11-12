import AppKit
import SwiftUI
import Carbon.HIToolbox
import MarginCore

/// Records a keyboard shortcut: click, then press the combination.
struct ShortcutRecorder: View {
    @Binding var display: String
    var onRecord: (_ keyCode: UInt32, _ modifiers: UInt32, _ display: String) -> Bool
    @State private var recording = false
    @State private var monitor: Any?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Button(recording ? "Press a shortcut…" : display) { recording ? stop() : start() }
                .accessibilityLabel(recording ? "Recording shortcut" : "Shortcut \(display). Click to change")
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        error = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) { stop(); return nil }
            let flags = event.modifierFlags.intersection([.control, .option, .command, .shift])
            guard !flags.intersection([.control, .option, .command]).isEmpty,
                  let key = event.charactersIgnoringModifiers, !key.isEmpty else { return nil }
            let shown = HotKey.displayString(flags: flags, key: event.keyCode == UInt16(kVK_Space) ? "Space" : key)
            if onRecord(UInt32(event.keyCode), HotKey.carbonModifiers(flags), shown) {
                display = shown
            } else {
                error = "That shortcut is not available."
            }
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

struct SettingsView: View {
    var onChange: () -> Void
    var onShortcut: (_ keyCode: UInt32, _ modifiers: UInt32, _ display: String) -> Bool
    let dataFolder: URL

    @State private var tabEnabled = Settings.tabEnabled
    @State private var showFocus = Settings.showFocusOnTab
    @State private var sound = Settings.soundEnabled
    @State private var login = LoginItem.isEnabled
    @State private var shortcut = Settings.hotKeyDisplay
    @State private var loginError: String?
    @State private var cliMessage: String?
    @State private var cliPath: String = CLIInstaller.installedLocation()?.path ?? CLIInstaller.helperURL.path

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show edge tab", isOn: $tabEnabled)
                    .onChange(of: tabEnabled) { _, v in Settings.tabEnabled = v; onChange() }
                Toggle("Show focus task on the tab", isOn: $showFocus)
                    .onChange(of: showFocus) { _, v in Settings.showFocusOnTab = v; onChange() }
                Toggle("Completion sound", isOn: $sound)
                    .onChange(of: sound) { _, v in Settings.soundEnabled = v }
                Toggle("Start at login", isOn: $login)
                    .onChange(of: login) { _, v in
                        do { try LoginItem.setEnabled(v); loginError = nil }
                        catch { loginError = error.localizedDescription; login = LoginItem.isEnabled }
                    }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
                LabeledContent("Shortcut") {
                    ShortcutRecorder(display: $shortcut, onRecord: onShortcut)
                }
            }
            Section("Data") {
                LabeledContent("Folder") {
                    HStack {
                        Text(dataFolder.path).textSelection(.enabled).foregroundStyle(.secondary)
                        Button("Open in Finder") { NSWorkspace.shared.open(dataFolder) }
                    }
                }
            }
            Section("AI agents") {
                LabeledContent("Command") {
                    HStack {
                        Button("Install margin command") {
                            do {
                                let link = try CLIInstaller.install()
                                cliPath = link.path
                                let dir = link.deletingLastPathComponent()
                                cliMessage = CLIInstaller.pathContains(dir)
                                    ? "Installed at \(link.path)"
                                    : "Installed at \(link.path). Add \(dir.path) to your PATH."
                            } catch {
                                cliMessage = error.localizedDescription
                            }
                        }
                    }
                }
                if let cliMessage { Text(cliMessage).font(.caption).foregroundStyle(.secondary) }
                copyRow("Claude Code", "claude mcp add --scope user margin -- \(cliPath) mcp")
                copyRow("Codex", "codex mcp add margin -- \(cliPath) mcp")
                copyRow("Instructions", dataFolder.appendingPathComponent("AGENTS.md").path)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func copyRow(_ title: String, _ text: String) -> some View {
        LabeledContent(title) {
            HStack {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(.borderless)
                .help("Copy")
                .accessibilityLabel("Copy \(title)")
            }
        }
    }
}

/// The Settings window. The app becomes active only while this window is open.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let makeView: () -> SettingsView

    init(makeView: @escaping () -> SettingsView) {
        self.makeView = makeView
    }

    func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: makeView()))
            w.title = "\(AppInfo.name) Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
