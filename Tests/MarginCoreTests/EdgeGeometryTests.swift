import Foundation
import Testing
@testable import MarginCore

private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

@Test func snapPicksNearestEdge() {
    #expect(EdgeGeometry.snap(point: CGPoint(x: 1500, y: 491), in: screen, displayID: 1) == TabPlacement(edge: .right, fraction: 0.5, displayID: 1))
    #expect(EdgeGeometry.snap(point: CGPoint(x: 700, y: 975), in: screen, displayID: 1).edge == .top)
    #expect(EdgeGeometry.snap(point: CGPoint(x: 5, y: 300), in: screen, displayID: 1).edge == .left)
    #expect(EdgeGeometry.snap(point: CGPoint(x: 700, y: 4), in: screen, displayID: 1).edge == .bottom)
    let far = EdgeGeometry.snap(point: CGPoint(x: -50, y: 2000), in: screen, displayID: 1)
    #expect(far.fraction <= 1); #expect(far.fraction >= 0)
}
@Test func tabStaysInsideAtCorners() {
    let f = EdgeGeometry.tabFrame(TabPlacement(edge: .right, fraction: 1, displayID: 1), length: 120, thickness: 8, in: screen)
    #expect(screen.contains(f)); #expect(f.maxX == screen.maxX); #expect(f.size == CGSize(width: 8, height: 120))
    let t = EdgeGeometry.tabFrame(TabPlacement(edge: .top, fraction: 0, displayID: 1), length: 120, thickness: 8, in: screen)
    #expect(t.minX == 0); #expect(t.maxY == screen.maxY)
}
@Test func panelIsClampedAndOnInnerSide() {
    let tab = EdgeGeometry.tabFrame(TabPlacement(edge: .right, fraction: 0.98, displayID: 1), length: 120, thickness: 8, in: screen)
    let p = EdgeGeometry.panelFrame(tab: tab, edge: .right, size: CGSize(width: 300, height: 600), in: screen, gap: 8)
    #expect(screen.contains(p)); #expect(p.maxX == screen.maxX - 8)
    let l = EdgeGeometry.panelFrame(tab: CGRect(x: 0, y: 400, width: 8, height: 120), edge: .left, size: CGSize(width: 300, height: 200), in: screen, gap: 8)
    #expect(l.minX == 8); #expect(l.midY == 460)
    let big = EdgeGeometry.clamp(CGRect(x: -10, y: -10, width: 300, height: 5000), into: screen)
    #expect(big.height == screen.height); #expect(screen.contains(big))
    #expect(EdgeGeometry.maxPanelHeight(visible: screen) == 982 * 0.7)
}
@Test func offsetScreenOrigin() {
    let left = CGRect(x: -1920, y: 100, width: 1920, height: 1080)
    let f = EdgeGeometry.tabFrame(EdgeGeometry.snap(point: CGPoint(x: -1915, y: 600), in: left, displayID: 2), length: 120, thickness: 8, in: left)
    #expect(left.contains(f)); #expect(f.minX == -1920)
}
