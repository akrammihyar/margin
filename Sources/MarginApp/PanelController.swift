import AppKit
import SwiftUI
import MarginCore

/// Owns the floating panel: where it is, when it shows, and the pinned state.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    /// What the panel is attached to.
    struct Anchor {
        var rect: CGRect
        var edge: ScreenEdge
        var visible: CGRect
        /// Distance from the screen edge to the panel.
        var gap: CGFloat = PanelMetrics.edgeGap
    }

    private let model: AppModel
    private let window = FloatingPanel()
    private var hosting: TrackingHostingView<AnyView>!
    private var anchor: Anchor?
    private var closing = false
    private var dragOffset: CGPoint?
    private var contentSize: CGSize?

    var onVisibilityChange: ((Bool) -> Void)?
    var onPointer: ((Bool) -> Void)?
    /// Gives the anchor for an unpinned panel (the tab, or the menu bar icon).
    var anchorProvider: (() -> Anchor)?

    init(model: AppModel) {
        self.model = model
        super.init()
        window.delegate = self
        window.onEscape = { [weak self] in self?.escape() }
        model.isPinned = Settings.pinned
        model.onTogglePin = { [weak self] in self?.togglePin() }
        model.onRequestClose = { [weak self] in self?.escape() }
        rebuildContent(maxHeight: 600)
    }

    private func rebuildContent(maxHeight: CGFloat) {
        let root = PanelView(model: model, maxHeight: maxHeight, onDrag: { [weak self] phase in self?.drag(phase) })
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { [weak self] size in
                // The laid-out size of the fixed-size content is its ideal size.
                if size.width > 2 * PanelMetrics.pad + 100 { self?.contentSize = size }
                self?.layout(animated: false)
            }
        if hosting == nil {
            hosting = TrackingHostingView(rootView: AnyView(root))
            hosting.onPointer = { [weak self] inside in self?.onPointer?(inside) }
            hosting.sizingOptions = [.intrinsicContentSize]
            window.contentView = hosting
        } else {
            hosting.rootView = AnyView(root)
        }
    }

    // MARK: State

    var isVisible: Bool { window.isVisible && !closing }
    var isPinned: Bool { model.isPinned }
    /// The window frame, including the transparent space around the glass.
    var frame: CGRect { window.frame }

    /// True while a text field in the panel has the keyboard.
    var isEditingText: Bool {
        window.isKeyWindow && window.firstResponder is NSTextView
    }

    // MARK: Show and hide

    func show(anchor newAnchor: Anchor, focusInput: Bool) {
        closing = false
        // Always refresh: a pinned panel uses the anchor as its fallback screen.
        anchor = newAnchor
        rebuildContent(maxHeight: EdgeGeometry.maxPanelHeight(visible: anchor!.visible))
        let wasVisible = window.isVisible
        model.panelEdge = isPinned ? nil : anchor!.edge
        window.alphaValue = 1
        window.setFrame(targetFrame(), display: true)
        if !wasVisible {
            model.panelShown = false
            window.orderFrontRegardless()
            withAnimation(appearAnimation) { model.panelShown = true }
            onVisibilityChange?(true)
        } else {
            model.panelShown = true
        }
        if focusInput {
            window.makeKeyAndOrderFront(nil)
            model.requestAddFocus()
        }
    }

    func hide() {
        guard window.isVisible, !closing else { return }
        model.flushNote()
        closing = true
        withAnimation(.easeIn(duration: 0.14)) { model.panelShown = false }
        // One-shot: take the window off screen when the fade is complete.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            guard let self, self.closing else { return }
            self.closing = false
            self.window.orderOut(nil)
            self.onVisibilityChange?(false)
        }
    }

    private var appearAnimation: Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.32, bounce: 0.18)
    }

    /// Esc: close, unless the panel is pinned. A pinned panel gives the keyboard back.
    private func escape() {
        if isPinned {
            // Give the keyboard back to the app that the owner was in.
            window.makeFirstResponder(nil)
            window.orderOut(nil)
            window.orderFrontRegardless()
        } else {
            hide()
        }
    }

    // MARK: Layout

    private func visiblePanelSize() -> CGSize {
        var fitting = hosting.fittingSize
        // The fitting size can be empty while the display is asleep. Use the last good size then.
        if fitting.width < 2 * PanelMetrics.pad + 100, let contentSize { fitting = contentSize }
        return CGSize(width: max(fitting.width - 2 * PanelMetrics.pad, 100), height: max(fitting.height - 2 * PanelMetrics.pad, 60))
    }

    private func targetFrame() -> CGRect {
        guard let anchor else { return window.frame }
        let size = visiblePanelSize()
        var panel: CGRect
        if isPinned, let topLeft = Settings.pinnedTopLeft {
            panel = EdgeGeometry.clamp(CGRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height),
                                       into: screenVisibleFrame(containing: topLeft) ?? anchor.visible)
        } else {
            panel = EdgeGeometry.panelFrame(tab: anchor.rect, edge: anchor.edge, size: size, in: anchor.visible, gap: anchor.gap)
        }
        return panel.insetBy(dx: -PanelMetrics.pad, dy: -PanelMetrics.pad)
    }

    private func screenVisibleFrame(containing point: CGPoint) -> CGRect? {
        NSScreen.screens.first(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(point) })?.visibleFrame
    }

    /// Called when the content size changes, and after a display change.
    func layout(animated: Bool) {
        guard window.isVisible, !closing, dragOffset == nil else { return }
        let target = targetFrame()
        guard target != window.frame else { return }
        window.setFrame(target, display: true, animate: false)
    }

    func displaysChanged() {
        if let provider = anchorProvider { anchor = provider() }
        layout(animated: false)
    }

    // MARK: Pin

    func togglePin() {
        let pin = !model.isPinned
        if pin {
            let visible = window.frame.insetBy(dx: PanelMetrics.pad, dy: PanelMetrics.pad)
            Settings.pinnedTopLeft = CGPoint(x: visible.minX, y: visible.maxY)
        }
        model.isPinned = pin
        Settings.pinned = pin
        model.panelEdge = nil
        onVisibilityChange?(window.isVisible)   // the tab shows again next to a pinned panel
        if !pin {
            if let provider = anchorProvider { anchor = provider() }
            window.setFrame(targetFrame(), display: true, animate: true)
            if !window.frame.contains(NSEvent.mouseLocation) && !isEditingText { hide() }
        }
    }

    /// Shows a pinned panel after launch.
    func restorePinned(anchor: Anchor) {
        guard Settings.pinned else { return }
        show(anchor: anchor, focusInput: false)
    }

    /// Dragging the header moves a pinned panel.
    private func drag(_ phase: PanelView.DragPhase) {
        guard isPinned else { return }
        let mouse = NSEvent.mouseLocation
        switch phase {
        case .began, .moved:
            if dragOffset == nil { dragOffset = CGPoint(x: mouse.x - window.frame.minX, y: mouse.y - window.frame.minY) }
            if let o = dragOffset { window.setFrameOrigin(CGPoint(x: mouse.x - o.x, y: mouse.y - o.y)) }
        case .ended:
            dragOffset = nil
            let visible = window.frame.insetBy(dx: PanelMetrics.pad, dy: PanelMetrics.pad)
            Settings.pinnedTopLeft = CGPoint(x: visible.minX, y: visible.maxY)
            layout(animated: false)
        }
    }

    // MARK: Keyboard focus

    func focusInput() {
        window.makeKeyAndOrderFront(nil)
        model.requestAddFocus()
    }

    func windowDidResignKey(_ notification: Notification) {
        // Like a popover: when the owner clicks a different app, an unpinned panel closes.
        guard !isPinned, window.isVisible, !window.frame.contains(NSEvent.mouseLocation) else { return }
        hide()
    }
}
