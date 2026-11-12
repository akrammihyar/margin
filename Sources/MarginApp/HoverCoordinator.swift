import Foundation

/// Opens the panel after the pointer rests on the tab, and closes it after the pointer leaves.
/// Uses one-shot work items only.
final class HoverCoordinator {
    private let openDelay: TimeInterval
    private let closeDelay: TimeInterval
    private let open: () -> Void
    private let close: () -> Void
    private let canClose: () -> Bool
    private var pendingOpen: DispatchWorkItem?
    private var pendingClose: DispatchWorkItem?

    init(openDelay: TimeInterval = 0.15, closeDelay: TimeInterval = 0.30,
         open: @escaping () -> Void, close: @escaping () -> Void, canClose: @escaping () -> Bool) {
        self.openDelay = openDelay
        self.closeDelay = closeDelay
        self.open = open
        self.close = close
        self.canClose = canClose
    }

    /// The pointer entered the tab (`opens` true) or the panel (`opens` false).
    func pointerEntered(opens: Bool) {
        pendingClose?.cancel()
        pendingClose = nil
        guard opens, pendingOpen == nil else { return }
        let item = DispatchWorkItem { [weak self] in
            self?.pendingOpen = nil
            self?.open()
        }
        pendingOpen = item
        DispatchQueue.main.asyncAfter(deadline: .now() + openDelay, execute: item)
    }

    func pointerExited() {
        pendingOpen?.cancel()
        pendingOpen = nil
        scheduleClose()
    }

    private func scheduleClose() {
        pendingClose?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingClose = nil
            // A menu or a drag is in progress: look again later.
            if RunLoop.current.currentMode == .eventTracking {
                self.scheduleClose()
                return
            }
            if self.canClose() { self.close() }
        }
        pendingClose = item
        DispatchQueue.main.asyncAfter(deadline: .now() + closeDelay, execute: item)
    }

    func cancel() {
        pendingOpen?.cancel(); pendingOpen = nil
        pendingClose?.cancel(); pendingClose = nil
    }
}
