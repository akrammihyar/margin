import AppKit

/// Tells the app when the calendar day can have changed: at midnight, after wake,
/// and after a clock or time zone change. Uses notifications and one one-shot
/// wall-clock deadline per day. No polling.
final class DayClock {
    private let onChange: () -> Void
    private let now: () -> Date
    private let calendar: Calendar
    private var midnight: DispatchWorkItem?
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []

    init(now: @escaping () -> Date, calendar: Calendar, onChange: @escaping () -> Void) {
        self.now = now
        self.calendar = calendar
        self.onChange = onChange
        let center = NotificationCenter.default
        for name in [Notification.Name.NSCalendarDayChanged, .NSSystemTimeZoneDidChange, .NSSystemClockDidChange] {
            tokens.append((center, center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.fire() }))
        }
        let ws = NSWorkspace.shared.notificationCenter
        tokens.append((ws, ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.fire() }))
        scheduleMidnight()
    }

    private func fire() {
        onChange()
        scheduleMidnight()
    }

    private func scheduleMidnight() {
        midnight?.cancel()
        let current = now()
        guard let next = calendar.nextDate(after: current, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime) else { return }
        let item = DispatchWorkItem { [weak self] in self?.fire() }
        midnight = item
        let delay = max(next.timeIntervalSince(current), 0) + 0.5
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + delay, execute: item)
    }

    deinit {
        midnight?.cancel()
        for (center, token) in tokens { center.removeObserver(token) }
    }
}
