// Draws the app icon and writes an .iconset folder. Usage: swift make-icon.swift <output.iconset>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func draw(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(pixels)
    let inset = s * 0.1
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGradient(colors: [NSColor(red: 0.36, green: 0.42, blue: 0.95, alpha: 1), NSColor(red: 0.18, green: 0.20, blue: 0.55, alpha: 1)])!
        .draw(in: path, angle: -90)

    // Three list rows; the first one is completed.
    let rowH = rect.height * 0.085
    let left = rect.minX + rect.width * 0.22
    for i in 0..<3 {
        let y = rect.maxY - rect.height * (0.33 + CGFloat(i) * 0.2)
        let circle = CGRect(x: left, y: y - rowH, width: rowH * 2, height: rowH * 2)
        let line = NSBezierPath(roundedRect: CGRect(x: left + rowH * 3, y: y - rowH * 0.45, width: rect.width * (i == 1 ? 0.36 : 0.28), height: rowH * 0.9),
                                xRadius: rowH * 0.45, yRadius: rowH * 0.45)
        if i == 0 {
            NSColor.white.setFill()
            NSBezierPath(ovalIn: circle).fill()
            NSColor.white.withAlphaComponent(0.45).setFill()
            line.fill()
        } else {
            NSColor.white.withAlphaComponent(0.9).setStroke()
            let ring = NSBezierPath(ovalIn: circle.insetBy(dx: rowH * 0.18, dy: rowH * 0.18))
            ring.lineWidth = rowH * 0.36
            ring.stroke()
            NSColor.white.withAlphaComponent(0.9).setFill()
            line.fill()
        }
    }
    // The "margin" line at the right edge.
    NSColor.white.withAlphaComponent(0.9).setFill()
    NSBezierPath(roundedRect: CGRect(x: rect.maxX - rect.width * 0.1, y: rect.midY - rect.height * 0.16, width: rect.width * 0.035, height: rect.height * 0.32),
                 xRadius: rect.width * 0.0175, yRadius: rect.width * 0.0175).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try draw(px).write(to: out.appendingPathComponent("icon_\(name).png"))
}
