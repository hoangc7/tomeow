import AppKit

/// The row of rounded segments at the top of the menu, one per focus round in the cycle.
/// Finished rounds are filled with the accent colour and the running one fills as it goes.
final class RoundsBar: NSView {
    private static let inset: CGFloat = 14
    private static let gap: CGFloat = 4
    private static let thickness: CGFloat = 3

    let steps: Int
    /// Rounds done, counting the running one fractionally: 2.5 is two full segments and half a third.
    var filled: Double = 0 {
        didSet {
            guard filled != oldValue else { return }
            needsDisplay = true
            setAccessibilityValue("\(Int(filled)) of \(steps) rounds done")
        }
    }

    init(steps: Int) {
        self.steps = steps
        super.init(frame: NSRect(x: 0, y: 0, width: 120, height: 16))
        autoresizingMask = .width  // the menu stretches it to its own width
        setAccessibilityElement(true)
        setAccessibilityRole(.progressIndicator)
        setAccessibilityLabel("Focus rounds")
        setAccessibilityValue("0 of \(steps) rounds done")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let track = bounds.insetBy(dx: Self.inset, dy: 0)
        let width = (track.width - Self.gap * CGFloat(steps - 1)) / CGFloat(steps)
        let radius = Self.thickness / 2
        for step in 0..<steps {
            let segment = NSRect(x: track.minX + CGFloat(step) * (width + Self.gap),
                                 y: (bounds.midY - radius).rounded(), width: width, height: Self.thickness)
            let capsule = NSBezierPath(roundedRect: segment, xRadius: radius, yRadius: radius)
            NSColor.quaternaryLabelColor.setFill()
            capsule.fill()

            let fill = min(max(filled - Double(step), 0), 1)
            guard fill > 0 else { continue }
            NSGraphicsContext.saveGraphicsState()
            capsule.addClip()  // a partly filled segment keeps its rounded ends
            NSColor.controlAccentColor.setFill()
            NSRect(x: segment.minX, y: segment.minY, width: segment.width * fill, height: segment.height).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}
