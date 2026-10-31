import AppKit

/// Pixel-art sprites drawn once from string grids, so the app ships no image assets.
/// Layers show them with nearest-neighbour scaling at 2 pt per pixel.
@MainActor
enum Sprites {
    private static let palette: [Character: (CGFloat, CGFloat, CGFloat)] = [
        "o": (0.96, 0.64, 0.27),  // ginger fur
        "d": (0.82, 0.45, 0.15),  // stripes and tail
        "w": (1.00, 0.96, 0.91),  // muzzle, chest, paws
        "p": (1.00, 0.56, 0.64),  // nose, inner ears
        "k": (0.16, 0.10, 0.07),  // eyes
        "r": (0.94, 0.30, 0.24),  // tomato
        "h": (1.00, 0.62, 0.54),  // tomato shine
        "s": (0.74, 0.18, 0.15),  // tomato shade
        "g": (0.40, 0.76, 0.37),  // leaf
    ]

    static let catSize = CGSize(width: 32, height: 24)
    static let iconSize = CGSize(width: 14, height: 14)

    private static let catBody = [
        "................",
        ".........o.....o",
        ".........op...po",
        "..d......ooooooo",
        ".d.......okoooko",
        ".d.dododooowpwoo",
        "..oooooooooooooo",
        "..ooooooooowwoo.",
        "...oooooooowwo..",
    ]
    private static let legs = [
        [".oo.........oo..", "ww............ww"],  // stretched
        ["...o.o....o.o...", "...w.w....w.w..."],  // passing
        [".....oo..oo.....", ".....ww..ww....."],  // gathered
    ]
    private static let blank = String(repeating: ".", count: 16)

    /// Four-frame gallop; the passing frames lift the cat a pixel so the run bounces.
    static let run: [CGImage] = [(0, false), (1, true), (2, false), (1, true)].map { frame in
        let rows = catBody + legs[frame.0] + [blank]
        return image(frame.1 ? Array(rows.dropFirst()) + [blank] : rows)
    }

    static let sit = image([
        "................",
        ".........o.....o",
        ".........op...po",
        ".........ooooooo",
        ".........okoooko",
        ".........oowpwoo",
        "........oooooooo",
        ".......ooooowwo.",
        "......dodoowwwo.",
        ".d....oooooowwo.",
        ".d....oooooowwo.",
        "..ddddowwoowwo..",
    ])

    static let tomato = image([
        "...g...",
        ".rgggr.",
        "rhrgrrr",
        "rhrrrrr",
        "rrrrrrr",
        "rrrrrrs",
        ".rrrss.",
    ])

    static let catFace = image([
        "o.....o",
        "op...po",
        "ooooooo",
        "okoooko",
        "oowpwoo",
        "ooooooo",
        ".ooooo.",
    ])

    private static func image(_ rows: [String]) -> CGImage {
        let width = rows[0].count, height = rows.count
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for (y, row) in rows.enumerated() {
            for (x, key) in row.enumerated() {
                guard let (r, g, b) = palette[key] else { continue }
                ctx.setFillColor(red: r, green: g, blue: b, alpha: 1)
                ctx.fill(CGRect(x: x, y: height - 1 - y, width: 1, height: 1))
            }
        }
        return ctx.makeImage()!
    }

    /// A white speech bubble whose tail points left at the cat.
    static func bubble(_ text: String, scale: CGFloat) -> (image: CGImage, size: CGSize) {
        let base = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 12) } ?? base
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(white: 0.12, alpha: 1)]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let tail: CGFloat = 5, padding: CGFloat = 9
        let size = CGSize(width: ceil(textSize.width) + 2 * padding + tail, height: 22)

        let ctx = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale),
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.scaleBy(x: scale, y: scale)
        let shape = CGMutablePath()
        shape.addRoundedRect(in: CGRect(x: tail, y: 0, width: size.width - tail, height: size.height),
                             cornerWidth: 9, cornerHeight: 9)
        shape.addLines(between: [CGPoint(x: tail + 2, y: 15), CGPoint(x: 0, y: 10), CGPoint(x: tail + 2, y: 7)])
        ctx.addPath(shape)
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fillPath()

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        (text as NSString).draw(at: CGPoint(x: tail + padding, y: (size.height - textSize.height) / 2),
                                withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
        return (ctx.makeImage()!, size)
    }
}
