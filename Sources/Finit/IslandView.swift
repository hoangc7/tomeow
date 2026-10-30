import AppKit

/// The black island around the notch: a tomato and progress ring on the left, ▶ or the
/// countdown on the right, and a stage below the notch where the cat appears.
@MainActor
final class IslandView: NSView {
    var onClick: (@MainActor () -> Void)?
    var onMenu: (@MainActor () -> NSMenu)?

    private(set) var geometry: NotchGeometry
    private var windowSize = IslandSize.compact
    private var shapeSize = IslandSize.compact  // the outline lags the window while it morphs
    private var morphID = 0

    private let island = CAShapeLayer()
    private let icon = CALayer()
    private let track = CAShapeLayer()
    private let ring = CAShapeLayer()
    private let play = CAShapeLayer()
    private let time = Countdown()
    private let stage = CALayer()
    private let stageMask = CAShapeLayer()
    private var shownPhase: PomodoroTimer.Phase?

    private var cat: CatShow?
    private var pendingCat: CatShow.Kind?  // set while the island opens for it
    private var catID = 0

    private static let tomatoRed = CGColor(srgbRed: 0.94, green: 0.33, blue: 0.27, alpha: 1)
    private static let mint = CGColor(srgbRed: 0.47, green: 0.86, blue: 0.55, alpha: 1)
    private static let white = CGColor(gray: 1, alpha: 1)

    init(geometry: NotchGeometry) {
        self.geometry = geometry
        super.init(frame: .zero)
        wantsLayer = true

        island.fillColor = CGColor(gray: 0, alpha: 1)

        let circle = CGMutablePath()
        circle.addArc(center: CGPoint(x: 12, y: 12), radius: 10, startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi, clockwise: true)
        for layer in [track, ring] {
            layer.bounds = CGRect(x: 0, y: 0, width: 24, height: 24)
            layer.path = circle
            layer.fillColor = nil
            layer.lineWidth = 2
            layer.lineCap = .round
        }
        track.strokeColor = CGColor(gray: 1, alpha: 0.16)

        icon.bounds.size = Sprites.iconSize
        icon.magnificationFilter = .nearest

        let triangle = CGMutablePath()
        triangle.addLines(between: [CGPoint(x: 2, y: 1), CGPoint(x: 11, y: 6), CGPoint(x: 2, y: 11)])
        triangle.closeSubpath()
        play.bounds = CGRect(x: 0, y: 0, width: 12, height: 12)
        play.path = triangle
        play.fillColor = Self.white
        play.strokeColor = Self.white
        play.lineWidth = 2
        play.lineJoin = .round

        stage.mask = stageMask
        for layer in [island, track, ring, icon, play, time.layer, stage] { self.layer!.addSublayer(layer) }
        applyScale()
        setAccessibilityRole(.button)
        setAccessibilityLabel("Finit Pomodoro timer")
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: Content

    func update(phase: PomodoroTimer.Phase, seconds: Int, progress: Double, paused: Bool) {
        instant {
            if phase != shownPhase {
                shownPhase = phase
                let resting = phase == .rest
                icon.contents = resting ? Sprites.catFace : Sprites.tomato
                for layer in [track, ring, time.layer] { layer.isHidden = phase == .idle }
                play.isHidden = phase != .idle
                ring.strokeColor = resting ? Self.mint : Self.tomatoRed
                time.setStyle(color: resting ? Self.mint : Self.white, scale: scale)
            }
            guard phase != .idle else { return }
            time.show(String(format: "%d:%02d", seconds / 60, seconds % 60))
            time.layer.opacity = paused ? 0.45 : 1
            ring.strokeEnd = progress
        }
    }

    // MARK: Cat

    /// The cat on stage (or about to be), unless it is already on its way out.
    var catKind: CatShow.Kind? {
        if let cat { return cat.isLeaving ? nil : cat.kind }
        return pendingCat
    }

    /// Opens the island, runs the cat in, and sends it away again after `hold` seconds.
    func presentCat(_ kind: CatShow.Kind, text: String, hold: TimeInterval = 4.5) {
        removeCat()
        catID &+= 1
        let id = catID
        pendingCat = kind
        morph(to: .expanded) { [weak self] in
            guard let self, catID == id else { return }
            pendingCat = nil
            let show = CatShow(kind: kind, text: text, in: stage,
                               center: CGPoint(x: bounds.midX, y: NotchGeometry.drop / 2),
                               notch: CGPoint(x: bounds.midX, y: bounds.maxY - geometry.notchHeight / 2),
                               leftEdge: bounds.midX - geometry.islandSize(.expanded).width / 2,
                               scale: geometry.scale)
            cat = show
            after(show.enter() + hold) { [weak self] in
                guard let self, catID == id else { return }
                dismissCat()
            }
        }
    }

    /// Sends the cat off, then folds the island back up.
    func dismissCat() {
        guard catKind != nil else { return }
        catID &+= 1
        let id = catID
        pendingCat = nil
        after(cat?.leave() ?? 0) { [weak self] in
            guard let self, catID == id else { return }
            removeCat()
            morph(to: .compact) {}
        }
    }

    private func removeCat() {
        cat?.remove()
        cat = nil
        pendingCat = nil
    }

    // MARK: Geometry

    func place() {
        instant {
            window?.setFrame(geometry.windowFrame(windowSize), display: true)
            relayout()
        }
    }

    func setGeometry(_ newGeometry: NotchGeometry) {
        guard newGeometry != geometry else { return }
        geometry = newGeometry
        removeCat()
        catID &+= 1
        morphID &+= 1
        island.removeAllAnimations()
        windowSize = .compact
        shapeSize = .compact
        applyScale()
        place()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        instant(relayout)
    }

    private func relayout() {
        for layer in [island, stage, stageMask] { layer.frame = bounds }
        island.path = outline(shapeSize)
        stageMask.path = outline(.expanded)
        let y = bounds.maxY - geometry.notchHeight / 2
        let offset = geometry.notchWidth / 2 + NotchGeometry.wing / 2
        for layer in [icon, track, ring] { layer.position = CGPoint(x: bounds.midX - offset, y: y) }
        play.position = CGPoint(x: bounds.midX + offset + 1, y: y)
        time.layer.position = CGPoint(x: bounds.midX + offset, y: y)
    }

    /// The island's outline at `size`, hanging from the top centre of the current bounds.
    private func outline(_ size: IslandSize) -> CGPath {
        let box = geometry.islandSize(size)
        let ear = NotchGeometry.ear, radius: CGFloat = size == .compact ? 9 : 18
        let left = bounds.midX - box.width / 2, right = bounds.midX + box.width / 2
        let top = bounds.maxY, bottom = top - box.height
        let path = CGMutablePath()
        path.move(to: CGPoint(x: left - ear, y: top))
        path.addQuadCurve(to: CGPoint(x: left, y: top - ear), control: CGPoint(x: left, y: top))
        path.addLine(to: CGPoint(x: left, y: bottom + radius))
        path.addQuadCurve(to: CGPoint(x: left + radius, y: bottom), control: CGPoint(x: left, y: bottom))
        path.addLine(to: CGPoint(x: right - radius, y: bottom))
        path.addQuadCurve(to: CGPoint(x: right, y: bottom + radius), control: CGPoint(x: right, y: bottom))
        path.addLine(to: CGPoint(x: right, y: top - ear))
        path.addQuadCurve(to: CGPoint(x: right + ear, y: top), control: CGPoint(x: right, y: top))
        path.closeSubpath()
        return path
    }

    /// Animates the outline to `size`. The window grows before expanding and shrinks after
    /// collapsing, so it only covers the menu bar and the windows below while the cat is out.
    private func morph(to size: IslandSize, then done: @escaping @MainActor () -> Void) {
        morphID &+= 1
        let id = morphID
        var from = island.presentation()?.path ?? island.path
        if size == .expanded && windowSize == .compact {
            windowSize = .expanded
            place()  // the outline stays compact inside the bigger window until the spring opens it
            from = island.path
        }
        shapeSize = size
        let to = outline(size)
        let animation: CABasicAnimation
        if size == .expanded {
            let spring = CASpringAnimation(keyPath: "path")
            spring.damping = 20
            spring.stiffness = 300
            spring.duration = spring.settlingDuration
            animation = spring
        } else {
            animation = CABasicAnimation(keyPath: "path")
            animation.duration = 0.25
            animation.timingFunction = CAMediaTimingFunction(name: .easeIn)
        }
        animation.fromValue = from
        animation.toValue = to
        instant { island.path = to }
        island.add(animation, forKey: "morph")

        after(size == .expanded ? 0.3 : animation.duration) { [weak self] in
            guard let self, morphID == id else { return }
            if size == .compact {
                island.removeAnimation(forKey: "morph")
                windowSize = .compact
                place()
            }
            done()
        }
    }

    private var scale: CGFloat { window?.backingScaleFactor ?? geometry.scale }

    private func applyScale() {
        for layer in [island, track, ring, play, stageMask] { layer.contentsScale = scale }
        shownPhase = nil  // re-render the countdown glyphs at the new scale on the next update
    }

    // MARK: NSView

    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {}

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        applyScale()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { return rightMouseDown(with: event) }
        onClick?()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = onMenu?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

/// The countdown text, assembled from glyphs rendered once per colour, so a tick only swaps
/// layer contents instead of typesetting and drawing text (most of a tick's cost otherwise).
@MainActor
final class Countdown {
    static let size = CGSize(width: 52, height: 16)

    let layer = CALayer()
    private var cells: [CALayer] = []
    private var glyphs: [Character: CGImage] = [:]
    private var widths: [Character: CGFloat] = [:]
    private var style: (CGColor, CGFloat)?
    private var shown = ""

    init() {
        layer.bounds.size = Self.size
    }

    func setStyle(color: CGColor, scale: CGFloat) {
        guard style.map({ $0.0 != color || $0.1 != scale }) ?? true else { return }
        style = (color, scale)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(cgColor: color)!]
        for glyph in "0123456789:" {
            let string = String(glyph) as NSString
            let width = ceil(string.size(withAttributes: attributes).width)
            let ctx = CGContext(data: nil, width: Int(width * scale), height: Int(Self.size.height * scale),
                                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.scaleBy(x: scale, y: scale)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            string.draw(at: .zero, withAttributes: attributes)
            NSGraphicsContext.restoreGraphicsState()
            glyphs[glyph] = ctx.makeImage()
            widths[glyph] = width
        }
        let text = shown
        shown = ""
        show(text)
    }

    func show(_ text: String) {
        guard text != shown else { return }
        shown = text
        while cells.count < text.count {
            let cell = CALayer()
            cells.append(cell)
            layer.addSublayer(cell)
        }
        var x = (Self.size.width - text.reduce(0) { $0 + (widths[$1] ?? 0) }) / 2
        for (index, cell) in cells.enumerated() {
            cell.isHidden = index >= text.count
            guard !cell.isHidden else { continue }
            let glyph = text[text.index(text.startIndex, offsetBy: index)]
            let width = widths[glyph] ?? 0
            cell.contents = glyphs[glyph]
            cell.frame = CGRect(x: x, y: 0, width: width, height: Self.size.height)
            x += width
        }
    }
}
