import Foundation
import CoreGraphics

public enum ScreenEdge: String, Codable, Sendable, CaseIterable {
    case left, right, top, bottom
    public var isVertical: Bool { self == .left || self == .right }
}

/// Where the edge tab is: an edge, a position along it (0...1), and a display.
/// `fraction` goes left to right on top/bottom edges and bottom to top on left/right edges.
public struct TabPlacement: Codable, Equatable, Sendable {
    public var edge: ScreenEdge
    public var fraction: Double
    public var displayID: UInt32
    public init(edge: ScreenEdge, fraction: Double, displayID: UInt32) {
        self.edge = edge; self.fraction = fraction; self.displayID = displayID
    }
}

/// Pure geometry for the tab and panel frames, in AppKit screen coordinates (origin bottom-left).
public enum EdgeGeometry {
    public static func snap(point: CGPoint, in screen: CGRect, displayID: UInt32) -> TabPlacement {
        let distances: [(ScreenEdge, CGFloat)] = [
            (.left, abs(point.x - screen.minX)),
            (.right, abs(screen.maxX - point.x)),
            (.bottom, abs(point.y - screen.minY)),
            (.top, abs(screen.maxY - point.y)),
        ]
        let edge = distances.min(by: { $0.1 < $1.1 })!.0
        let raw: CGFloat = edge.isVertical
            ? (screen.height > 0 ? (point.y - screen.minY) / screen.height : 0.5)
            : (screen.width > 0 ? (point.x - screen.minX) / screen.width : 0.5)
        return TabPlacement(edge: edge, fraction: Double(min(max(raw, 0), 1)), displayID: displayID)
    }

    public static func tabFrame(_ p: TabPlacement, length: CGFloat, thickness: CGFloat, in screen: CGRect) -> CGRect {
        let f = CGFloat(min(max(p.fraction, 0), 1))
        var frame: CGRect
        switch p.edge {
        case .left:
            frame = CGRect(x: screen.minX, y: screen.minY + f * screen.height - length / 2, width: thickness, height: length)
        case .right:
            frame = CGRect(x: screen.maxX - thickness, y: screen.minY + f * screen.height - length / 2, width: thickness, height: length)
        case .bottom:
            frame = CGRect(x: screen.minX + f * screen.width - length / 2, y: screen.minY, width: length, height: thickness)
        case .top:
            frame = CGRect(x: screen.minX + f * screen.width - length / 2, y: screen.maxY - thickness, width: length, height: thickness)
        }
        frame = clamp(frame, into: screen)
        return frame
    }

    /// The panel is on the inner side of the tab, centred on it along the edge, `gap` from the edge.
    public static func panelFrame(tab: CGRect, edge: ScreenEdge, size: CGSize, in visible: CGRect, gap: CGFloat) -> CGRect {
        var origin: CGPoint
        switch edge {
        case .left: origin = CGPoint(x: visible.minX + gap, y: tab.midY - size.height / 2)
        case .right: origin = CGPoint(x: visible.maxX - gap - size.width, y: tab.midY - size.height / 2)
        case .bottom: origin = CGPoint(x: tab.midX - size.width / 2, y: visible.minY + gap)
        case .top: origin = CGPoint(x: tab.midX - size.width / 2, y: visible.maxY - gap - size.height)
        }
        let inset = visible.insetBy(dx: min(gap, visible.width / 4), dy: min(gap, visible.height / 4))
        let bounds = edge.isVertical
            ? CGRect(x: visible.minX, y: inset.minY, width: visible.width, height: inset.height)
            : CGRect(x: inset.minX, y: visible.minY, width: inset.width, height: visible.height)
        origin = clamp(CGRect(origin: origin, size: size), into: bounds).origin
        return clamp(CGRect(origin: origin, size: size), into: visible)
    }

    /// Moves the frame inside `visible`, and reduces its size when it is larger.
    public static func clamp(_ frame: CGRect, into visible: CGRect) -> CGRect {
        var r = frame
        r.size.width = min(r.width, visible.width)
        r.size.height = min(r.height, visible.height)
        r.origin.x = min(max(r.minX, visible.minX), visible.maxX - r.width)
        r.origin.y = min(max(r.minY, visible.minY), visible.maxY - r.height)
        return r
    }

    public static func maxPanelHeight(visible: CGRect) -> CGFloat { visible.height * 0.7 }
}
