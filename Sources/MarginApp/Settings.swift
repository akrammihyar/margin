import AppKit
import Carbon.HIToolbox
import MarginCore

/// Typed access to the user defaults of the app.
enum Settings {
    private static let d = UserDefaults.standard

    private static func bool(_ key: String, default value: Bool) -> Bool {
        d.object(forKey: key) == nil ? value : d.bool(forKey: key)
    }

    static var tabEnabled: Bool {
        get { bool("tabEnabled", default: true) }
        set { d.set(newValue, forKey: "tabEnabled") }
    }
    static var showFocusOnTab: Bool {
        get { bool("showFocusOnTab", default: true) }
        set { d.set(newValue, forKey: "showFocusOnTab") }
    }
    static var soundEnabled: Bool {
        get { bool("soundEnabled", default: true) }
        set { d.set(newValue, forKey: "soundEnabled") }
    }
    static var pinned: Bool {
        get { bool("pinned", default: false) }
        set { d.set(newValue, forKey: "pinned") }
    }
    /// Top-left corner of the pinned panel, in screen coordinates.
    static var pinnedTopLeft: CGPoint? {
        get {
            guard d.object(forKey: "pinnedX") != nil else { return nil }
            return CGPoint(x: d.double(forKey: "pinnedX"), y: d.double(forKey: "pinnedY"))
        }
        set {
            if let p = newValue { d.set(p.x, forKey: "pinnedX"); d.set(p.y, forKey: "pinnedY") }
            else { d.removeObject(forKey: "pinnedX"); d.removeObject(forKey: "pinnedY") }
        }
    }
    static var tabPlacement: TabPlacement {
        get {
            if let data = d.data(forKey: "tabPlacement"), let p = try? JSONDecoder().decode(TabPlacement.self, from: data) { return p }
            return TabPlacement(edge: .right, fraction: 0.5, displayID: NSScreen.screens.first?.displayID ?? 0)
        }
        set { d.set(try? JSONEncoder().encode(newValue), forKey: "tabPlacement") }
    }
    static var hotKeyCode: UInt32 {
        get { d.object(forKey: "hotKeyCode") == nil ? UInt32(kVK_ANSI_M) : UInt32(d.integer(forKey: "hotKeyCode")) }
        set { d.set(Int(newValue), forKey: "hotKeyCode") }
    }
    static var hotKeyModifiers: UInt32 {
        get { d.object(forKey: "hotKeyModifiers") == nil ? UInt32(controlKey | optionKey) : UInt32(d.integer(forKey: "hotKeyModifiers")) }
        set { d.set(Int(newValue), forKey: "hotKeyModifiers") }
    }
    /// How the shortcut is shown, for example "⌃⌥M".
    static var hotKeyDisplay: String {
        get { d.string(forKey: "hotKeyDisplay") ?? "⌃⌥M" }
        set { d.set(newValue, forKey: "hotKeyDisplay") }
    }
}

extension NSScreen {
    var displayID: UInt32 {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
    static func with(displayID: UInt32) -> NSScreen? {
        screens.first { $0.displayID == displayID }
    }
}
