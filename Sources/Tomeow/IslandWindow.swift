import AppKit

enum IslandSize { case compact, expanded }

/// Where the island lives: around the notch, or around a small fake one on screens without a notch.
struct NotchGeometry: Equatable {
    static let ear: CGFloat = 6  // concave flare where the island meets the top of the screen
    static let wing: CGFloat = 56  // compact width on each side of the notch
    static let wideWing: CGFloat = 150  // expanded width on each side of the notch
    static let drop: CGFloat = 44  // extra height when expanded: the cat's stage

    var screen: CGRect
    var notchWidth: CGFloat
    var notchHeight: CGFloat
    var scale: CGFloat

    @MainActor static func current() -> NotchGeometry? {
        let screens = NSScreen.screens
        guard let screen = screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? screens.first else {
            return nil
        }
        let frame = screen.frame
        if screen.safeAreaInsets.top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            return NotchGeometry(screen: frame, notchWidth: frame.width - left.width - right.width,
                                 notchHeight: screen.safeAreaInsets.top, scale: screen.backingScaleFactor)
        }
        let menuBar = frame.maxY - screen.visibleFrame.maxY
        return NotchGeometry(screen: frame, notchWidth: 64, notchHeight: menuBar > 0 ? menuBar : NSStatusBar.system.thickness,
                             scale: screen.backingScaleFactor)
    }

    func islandSize(_ size: IslandSize) -> CGSize {
        switch size {
        case .compact: CGSize(width: notchWidth + 2 * Self.wing, height: notchHeight)
        case .expanded: CGSize(width: notchWidth + 2 * Self.wideWing, height: notchHeight + Self.drop)
        }
    }

    /// Centred on the notch and flush with the top of the screen.
    func windowFrame(_ size: IslandSize) -> CGRect {
        let island = islandSize(size)
        let width = island.width + 2 * Self.ear
        return CGRect(x: screen.midX - width / 2, y: screen.maxY - island.height, width: width, height: island.height)
    }
}

/// A borderless panel above the menu bar that never takes focus from the app you're working in.
final class IslandPanel: NSPanel {
    init(content: NSView) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        contentView = content
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // AppKit would otherwise push the window below the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Applies layer changes without Core Animation's implicit animations.
@MainActor func instant(_ changes: () -> Void) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    changes()
    CATransaction.commit()
}

@MainActor func after(_ seconds: TimeInterval, _ work: @escaping @MainActor () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { MainActor.assumeIsolated(work) }
}
