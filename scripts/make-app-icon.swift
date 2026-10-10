// Draws Overmind's app icon in the Pop style (an orange tile, an ink outline and hard shadow,
// a white cloud) and writes Sources/App/Resources/Assets.xcassets/AppIcon.appiconset.
// Run: swift scripts/make-app-icon.swift
import AppKit

let folder = URL(fileURLWithPath: "Sources/App/Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

func draw(_ size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ink = NSColor(red: 0.106, green: 0.086, blue: 0.075, alpha: 1)
    let orange = NSColor(red: 0.965, green: 0.510, blue: 0.122, alpha: 1)
    // macOS icon grid: the tile sits inside a 10% margin.
    let inset = s * 0.10, shadow = s * 0.035, line = max(1, s * 0.03)
    let tile = NSRect(x: inset, y: inset + shadow, width: s - 2 * inset - shadow, height: s - 2 * inset - shadow)
    let radius = tile.width * 0.225
    ink.setFill()
    NSBezierPath(roundedRect: tile.offsetBy(dx: shadow, dy: -shadow), xRadius: radius, yRadius: radius).fill()
    orange.setFill()
    let face = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
    face.fill()
    ink.setStroke()
    face.lineWidth = line
    face.stroke()
    let config = NSImage.SymbolConfiguration(pointSize: tile.width * 0.46, weight: .black)
        .applying(.init(paletteColors: [.white]))
    if let cloud = NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let box = NSRect(x: tile.midX - cloud.size.width / 2, y: tile.midY - cloud.size.height / 2,
                         width: cloud.size.width, height: cloud.size.height)
        cloud.draw(in: box)
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try draw(points * scale).write(to: folder.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: folder.appendingPathComponent("Contents.json"))
let catalog: [String: Any] = ["info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted])
    .write(to: folder.deletingLastPathComponent().appendingPathComponent("Contents.json"))
print("wrote \(images.count) icons")
