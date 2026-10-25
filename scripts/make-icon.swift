// Generates Resources/AppIcon.icns and docs/icon.png.
// Run: swift scripts/make-icon.swift
// The artwork is plain geometry (no SF Symbols, whose license forbids use in app icons):
// a disk-usage ring with a sparkle on a blue-to-teal rounded square.
import AppKit
import CoreGraphics

func drawIcon(size: CGFloat, in ctx: CGContext) {
    let s = size / 1024
    ctx.scaleBy(x: s, y: s)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    // macOS icon grid: 824×824 squircle-ish rounded rect centred in 1024, with a soft shadow.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28,
                  color: CGColor(colorSpace: space, components: [0, 0, 0, 0.35])!)
    ctx.addPath(tilePath)
    ctx.setFillColor(CGColor(colorSpace: space, components: [0.10, 0.25, 0.60, 1])!)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: space, colors: [
        CGColor(colorSpace: space, components: [0.13, 0.27, 0.72, 1])!,   // deep blue
        CGColor(colorSpace: space, components: [0.05, 0.62, 0.66, 1])!,   // teal
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])
    // Glossy top highlight.
    let gloss = CGGradient(colorsSpace: space, colors: [
        CGColor(colorSpace: space, components: [1, 1, 1, 0.18])!,
        CGColor(colorSpace: space, components: [1, 1, 1, 0])!,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gloss, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 560), options: [])
    ctx.restoreGState()

    // Disk-usage ring: faint track plus a bright arc (space being freed).
    let center = CGPoint(x: 512, y: 500)
    let radius: CGFloat = 250
    ctx.setLineCap(.round)
    ctx.setLineWidth(78)
    ctx.setStrokeColor(CGColor(colorSpace: space, components: [1, 1, 1, 0.22])!)
    ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()
    ctx.setStrokeColor(CGColor(colorSpace: space, components: [1, 1, 1, 1])!)
    ctx.addArc(center: center, radius: radius, startAngle: .pi / 2, endAngle: .pi / 2 - .pi * 1.3, clockwise: true)
    ctx.strokePath()

    // Four-point sparkle in the centre, plus a small one at the arc's end.
    func sparkle(at p: CGPoint, size r: CGFloat, alpha: CGFloat) {
        let path = CGMutablePath()
        let inner = r * 0.22
        path.move(to: CGPoint(x: p.x, y: p.y + r))
        path.addQuadCurve(to: CGPoint(x: p.x + r, y: p.y), control: CGPoint(x: p.x + inner, y: p.y + inner))
        path.addQuadCurve(to: CGPoint(x: p.x, y: p.y - r), control: CGPoint(x: p.x + inner, y: p.y - inner))
        path.addQuadCurve(to: CGPoint(x: p.x - r, y: p.y), control: CGPoint(x: p.x - inner, y: p.y - inner))
        path.addQuadCurve(to: CGPoint(x: p.x, y: p.y + r), control: CGPoint(x: p.x - inner, y: p.y + inner))
        ctx.addPath(path)
        ctx.setFillColor(CGColor(colorSpace: space, components: [1, 1, 1, alpha])!)
        ctx.fillPath()
    }
    sparkle(at: center, size: 150, alpha: 1)
    sparkle(at: CGPoint(x: 775, y: 765), size: 58, alpha: 0.95)
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    drawIcon(size: CGFloat(size), in: context.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try png(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
try png(size: 512).write(to: root.appendingPathComponent("docs/icon.png"))
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns and docs/icon.png" : "iconutil failed")
