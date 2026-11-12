import AppKit
import SwiftUI
import MarginCore

/// The view that receives the mouse for the tab: hover, click, and drag.
final class TabEventView: NSView {
    var onPointer: ((Bool) -> Void)?
    var onClick: (() -> Void)?
    var onPress: (() -> Void)?
    var onDragMoved: ((CGPoint) -> Void)?
    var onDragEnded: ((CGPoint) -> Void)?
    private var area: NSTrackingArea?
    private var downAt: CGPoint?
    private var dragging = false

    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let new = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(new)
        area = new
    }

    override func mouseEntered(with event: NSEvent) { if !dragging { onPointer?(true) } }
    override func mouseExited(with event: NSEvent) { if !dragging { onPointer?(false) } }

    override func mouseDown(with event: NSEvent) {
        downAt = NSEvent.mouseLocation
        dragging = false
        onPress?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let downAt else { return }
        let now = NSEvent.mouseLocation
        if !dragging && hypot(now.x - downAt.x, now.y - downAt.y) > 4 { dragging = true }
        if dragging { onDragMoved?(now) }
    }

    override func mouseUp(with event: NSEvent) {
        if dragging { onDragEnded?(NSEvent.mouseLocation) } else { onClick?() }
        dragging = false
        downAt = nil
    }
}

/// Owns the edge tab window: its position, drag-to-move, and what it shows.
@MainActor
final class EdgeTabController {
    private let model: AppModel
    private let window = FloatingPanel()
    private let state = TabState()
    private let events = TabEventView()
    private var draggingTab = false

    var onPointer: ((Bool) -> Void)?
    var onClick: (() -> Void)?
    var onPress: (() -> Void)?
    var onDragBegan: (() -> Void)?

    init(model: AppModel) {
        self.model = model
        window.allowsKey = false
        window.ignoresMouseEvents = false
        let hosting = NSHostingView(rootView: EdgeTabView(state: state))
        hosting.sizingOptions = []
        hosting.autoresizingMask = [.width, .height]
        events.addSubview(hosting)
        window.contentView = events
        hosting.frame = events.bounds

        events.onPointer = { [weak self] inside in
            guard let self else { return }
            self.state.hovering = inside
            self.onPointer?(inside)
        }
        events.onClick = { [weak self] in self?.onClick?() }
        events.onPress = { [weak self] in self?.onPress?() }
        events.onDragMoved = { [weak self] point in self?.dragMoved(to: point) }
        events.onDragEnded = { [weak self] point in self?.dragEnded(at: point) }
        refreshLayout()
    }

    var isEnabled: Bool {
        get { Settings.tabEnabled }
        set {
            Settings.tabEnabled = newValue
            refreshLayout()
        }
    }

    var edge: ScreenEdge { Settings.tabPlacement.edge }

    /// The display of the tab. The primary display is the fallback when the saved display is not connected.
    var screen: NSScreen? {
        NSScreen.with(displayID: Settings.tabPlacement.displayID) ?? NSScreen.screens.first
    }

    /// The thickness of the tab now: the panel opens next to it.
    var thickness: CGFloat { size().thickness }

    var tabFrame: CGRect { window.frame }

    private func size() -> (length: CGFloat, thickness: CGFloat) {
        TabMetrics.size(marks: state.marks.count, text: state.text)
    }

    /// Call after a display change, a focus task change, or a settings change.
    func refreshLayout(animated: Bool = false) {
        let focus = model.todayFocusText
        state.text = (focus != nil && Settings.showFocusOnTab) ? focus : nil
        state.marks = model.todayMarks
        let placement = Settings.tabPlacement
        state.edge = placement.edge
        guard isEnabled, let screen else {
            window.orderOut(nil)
            return
        }
        guard !draggingTab else { return }
        let (length, thickness) = size()
        let frame = EdgeGeometry.tabFrame(placement, length: length, thickness: thickness, in: screen.visibleFrame)
        if frame != window.frame {
            window.setFrame(frame, display: true, animate: animated && window.isVisible)
        }
        if !window.isVisible { window.orderFrontRegardless() }
    }

    // MARK: Drag to move

    private func dragMoved(to point: CGPoint) {
        if !draggingTab {
            draggingTab = true
            state.hovering = false
            onDragBegan?()
        }
        window.setFrameOrigin(CGPoint(x: point.x - window.frame.width / 2, y: point.y - window.frame.height / 2))
    }

    private func dragEnded(at point: CGPoint) {
        draggingTab = false
        guard let target = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? screen else { return }
        Settings.tabPlacement = EdgeGeometry.snap(point: point, in: target.visibleFrame, displayID: target.displayID)
        refreshLayout(animated: true)
    }
}
