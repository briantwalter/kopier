import AppKit
import Foundation

func draw(size: Int, menu: Bool) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let unit = CGFloat(size) / 32
    let ink = NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.20, alpha: 1)
    func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: NSColor) {
        if menu {
            NSGraphicsContext.current?.compositingOperation = color == ink ? .sourceOver : .clear
            NSColor.black.setFill()
        } else { color.setFill() }
        NSRect(x: CGFloat(x)*unit, y: CGFloat(32-y-h)*unit, width: CGFloat(w)*unit, height: CGFloat(h)*unit).fill()
    }
    let body = NSColor(calibratedRed: 0.76, green: 0.82, blue: 0.83, alpha: 1)
    let shade = NSColor(calibratedRed: 0.44, green: 0.55, blue: 0.59, alpha: 1)
    let mint = NSColor(calibratedRed: 0.33, green: 0.9, blue: 0.67, alpha: 1)
    if !menu {
        NSColor(calibratedRed: 0.13, green: 0.30, blue: 0.35, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: unit, y: unit, width: unit*30, height: unit*30), xRadius: unit*6, yRadius: unit*6).fill()
    }
    rect(7, 7, 17, 2, ink)
    rect(6, 9, 20, 3, ink)
    rect(5, 12, 22, 15, ink)
    rect(7, 13, 18, 12, body)
    rect(7, 10, 17, 2, shade)
    rect(9, 5, 12, 2, ink)
    rect(10, 6, 10, 2, .white)
    rect(8, 14, 9, 3, ink)
    rect(9, 15, 7, 1, mint)
    rect(21, 14, 2, 2, mint)
    rect(9, 19, 14, 2, ink)
    rect(10, 21, 12, 3, .white)
    rect(12, 22, 8, 1, shade)
    rect(7, 27, 4, 2, ink)
    rect(21, 27, 4, 2, ink)
    NSGraphicsContext.current?.compositingOperation = .sourceOver
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Assets")
let iconset = assets.appendingPathComponent("Kopier.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for n in [16,32,128,256,512] {
    try draw(size: n, menu: false).write(to: iconset.appendingPathComponent("icon_\(n)x\(n).png"))
    try draw(size: n*2, menu: false).write(to: iconset.appendingPathComponent("icon_\(n)x\(n)@2x.png"))
}
try draw(size: 64, menu: true).write(to: assets.appendingPathComponent("MenuIcon.png"))
