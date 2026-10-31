// Renders the app icon, a pixel-art tomato cat on a dark squircle, into an .icns file.
// Usage: swift Scripts/make-icon.swift Resources/AppIcon.icns
import AppKit

let art = [
    "........................",
    "............g...........",
    ".....R.....gG.....R.....",
    ".....RR....GG....RR.....",
    "....RpRR.GGGGGG.RRpR....",
    "....RppRGGgGGgGGRppR....",
    "....RRpRRGRGGRGRRpRR....",
    "....RRRRRRRRRRRRRRRR....",
    "...RRhhRRRRRRRRRRRRRs...",
    "..RRhRRRRRRRRRRRRRRRRs..",
    ".RRhRRRRRRRRRRRRRRRRRss.",
    ".RRRRRRwkRRRRRRwkRRRRss.",
    ".RRRRRRkkRRRRRRkkRRRRss.",
    ".RRRRRRkkRRRRRRkkRRRRss.",
    ".RRRRbbRRRRnnRRRRbbRRss.",
    ".RRRRRRRRRkRRkRRRRRRRss.",
    ".RRRRRRRRRRkkRRRRRRRsss.",
    ".RRRRRRRRRRRRRRRRRRssss.",
    "..RRRRRRRRRRRRRRRRssss..",
    "...RRRRRRRRRRRRRRssss...",
    "....sRRRRRRRRRRsssss....",
    ".....ssssssssssssss.....",
    ".......ssssssssss.......",
    "........................",
]

let palette: [Character: (CGFloat, CGFloat, CGFloat)] = [
    "R": (0.94, 0.30, 0.24),  // tomato
    "s": (0.76, 0.19, 0.16),  // shade
    "h": (1.00, 0.62, 0.54),  // shine
    "p": (1.00, 0.62, 0.68),  // inner ears
    "b": (1.00, 0.55, 0.52),  // blush
    "n": (1.00, 0.78, 0.80),  // nose
    "k": (0.17, 0.07, 0.06),  // eyes and mouth
    "w": (1.00, 1.00, 1.00),  // eye shine
    "G": (0.42, 0.78, 0.36),  // leaves
    "g": (0.26, 0.56, 0.24),  // stem
]

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func canvas(_ size: Int) -> CGContext {
    CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

/// The icon at 1024 px; smaller sizes are scaled down from it so the pixel grid never shows seams.
func master() -> CGImage {
    let ctx = canvas(1024)

    // Background: the rounded square of Apple's 1024 px icon grid, dark like the notch island.
    // macOS 26+ shows .icns icons in a grey frame unless they match this outline exactly (a superellipse
    // or a drop shadow is enough to fail), and it draws the shadow itself.
    let shape = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                       cornerWidth: 185.4, cornerHeight: 185.4, transform: nil)
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let fill = CGGradient(colorsSpace: space, colors: [CGColor(srgbRed: 0.20, green: 0.20, blue: 0.23, alpha: 1),
                                                       CGColor(srgbRed: 0.07, green: 0.07, blue: 0.09, alpha: 1)] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(fill, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])
    let glow = CGGradient(colorsSpace: space, colors: [CGColor(srgbRed: 1, green: 0.45, blue: 0.3, alpha: 0.28),
                                                       CGColor(srgbRed: 1, green: 0.45, blue: 0.3, alpha: 0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 470), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 470), endRadius: 400, options: [])
    ctx.restoreGState()

    // Artwork: 24 × 24 cells of 28 px (the outer ring is empty), centred, with a soft shadow of its own.
    let cell: CGFloat = 28, origin = (1024 - 24 * cell) / 2
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: CGColor(gray: 0, alpha: 0.5))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    for (row, line) in art.enumerated() {
        for (column, key) in line.enumerated() {
            guard let (r, g, b) = palette[key] else { continue }
            ctx.setFillColor(red: r, green: g, blue: b, alpha: 1)
            ctx.fill(CGRect(x: origin + CGFloat(column) * cell, y: origin + CGFloat(23 - row) * cell, width: cell, height: cell))
        }
    }
    ctx.endTransparencyLayer()
    ctx.restoreGState()
    return ctx.makeImage()!
}

func png(_ image: CGImage, size: Int) -> Data {
    let ctx = canvas(size)
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.icns")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let icon = master()
for points in [16, 32, 128, 256, 512] {
    try png(icon, size: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(icon, size: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print(iconutil.terminationStatus == 0 ? "Wrote \(output.path)" : "iconutil failed")
