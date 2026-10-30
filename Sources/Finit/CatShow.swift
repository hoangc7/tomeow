import AppKit

/// The pixel cat that announces breaks. Every motion is a Core Animation animation, so the
/// render server plays it and the app itself stays asleep while the cat runs.
@MainActor
final class CatShow {
    enum Kind { case breakTime, backToWork }

    let kind: Kind
    private(set) var isLeaving = false
    private let cat = CALayer()
    private let bubble = CALayer()
    private let notch: CGPoint  // hidden behind the notch
    private let sit: CGPoint
    private let offstage: CGPoint  // just past the island's left edge

    /// `center` is the middle of the stage below the notch; `leftEdge` is the island's left side.
    init(kind: Kind, text: String, in stage: CALayer, center: CGPoint, notch: CGPoint, leftEdge: CGFloat, scale: CGFloat) {
        self.kind = kind
        self.notch = notch
        let (image, size) = Sprites.bubble(text, scale: scale)
        let catWidth = Sprites.catSize.width
        // Cat and bubble are centred together under the notch.
        sit = CGPoint(x: (center.x - (catWidth + 4 + size.width) / 2 + catWidth / 2).rounded(), y: center.y)
        offstage = CGPoint(x: leftEdge - catWidth, y: center.y)

        instant {
            cat.bounds.size = Sprites.catSize
            cat.magnificationFilter = .nearest
            cat.contents = Sprites.sit
            cat.position = sit
            bubble.contents = image
            bubble.contentsScale = scale
            bubble.bounds.size = size
            bubble.anchorPoint = CGPoint(x: 0, y: 0.5)
            bubble.position = CGPoint(x: sit.x + catWidth / 2 + 2, y: sit.y + 3)
            stage.addSublayer(cat)
            stage.addSublayer(bubble)
        }
    }

    /// Runs the cat in and pops its bubble. Returns the time until both have settled.
    func enter() -> TimeInterval {
        let duration: TimeInterval
        switch kind {
        case .breakTime:  // drop out of the notch, then scamper left
            duration = 1.2
            cat.add(move([notch, CGPoint(x: notch.x, y: sit.y), sit], times: [0, 0.25, 1], duration: duration,
                         timing: [.init(name: .easeIn), .init(name: .linear)]), forKey: "move")
            cat.add(faceLeft(duration), forKey: "face")
            cat.add(fade([0, 1, 1], times: [0, 0.12, 1], duration: duration), forKey: "fade")
        case .backToWork:  // trot in from the left edge
            duration = 1.1
            cat.add(move([offstage, sit], times: [0, 1], duration: duration), forKey: "move")
        }
        cat.add(runCycle(duration), forKey: "run")

        let start = bubble.convertTime(CACurrentMediaTime(), from: nil) + duration + 0.05
        let pop = CASpringAnimation(keyPath: "transform.scale")
        pop.fromValue = 0.3
        pop.toValue = 1
        pop.damping = 12
        pop.stiffness = 320
        pop.duration = pop.settlingDuration
        let appear = CABasicAnimation(keyPath: "opacity")
        appear.fromValue = 0
        appear.toValue = 1
        appear.duration = 0.1
        for (key, animation) in [("pop", pop), ("appear", appear)] {
            animation.beginTime = start
            animation.fillMode = .backwards
            bubble.add(animation, forKey: key)
        }
        return duration + 0.4
    }

    /// Sends the cat away. Returns how long that takes.
    func leave() -> TimeInterval {
        isLeaving = true
        let from = cat.presentation()?.position ?? cat.position
        bubble.removeAllAnimations()
        bubble.add(fade([1, 0], times: [0, 1], duration: 0.15), forKey: "fade")
        instant { bubble.opacity = 0 }

        let duration: TimeInterval
        switch kind {
        case .breakTime:  // dash off to the left
            duration = 0.7
            cat.add(move([from, offstage], times: [0, 1], duration: duration), forKey: "move")
            instant { cat.position = offstage; cat.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1)) }
        case .backToWork:  // run to the notch and hop back inside
            duration = 0.8
            let below = CGPoint(x: notch.x, y: sit.y)
            cat.add(move([from, below, notch], times: [0, 0.7, 1], duration: duration,
                         timing: [.init(name: .linear), .init(name: .easeOut)]), forKey: "move")
            cat.add(fade([1, 1, 0], times: [0, 0.7, 1], duration: duration), forKey: "fade")
            instant { cat.position = notch; cat.opacity = 0 }
        }
        cat.add(runCycle(duration), forKey: "run")
        return duration
    }

    func remove() {
        instant {
            cat.removeFromSuperlayer()
            bubble.removeFromSuperlayer()
        }
    }

    private func runCycle(_ duration: TimeInterval) -> CAAnimation {
        let run = CAKeyframeAnimation(keyPath: "contents")
        run.values = Sprites.run
        run.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        run.calculationMode = .discrete
        run.duration = 0.4
        run.repeatCount = Float(duration / run.duration)
        return run
    }

    private func move(_ points: [CGPoint], times: [NSNumber], duration: TimeInterval,
                      timing: [CAMediaTimingFunction]? = nil) -> CAAnimation {
        let move = CAKeyframeAnimation(keyPath: "position")
        move.values = points.map { NSValue(point: $0) }
        move.keyTimes = times
        move.timingFunctions = timing
        move.duration = duration
        return move
    }

    private func fade(_ values: [Float], times: [NSNumber], duration: TimeInterval) -> CAAnimation {
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = values
        fade.keyTimes = times
        fade.duration = duration
        return fade
    }

    /// The sprite faces right; mirror it while it runs left.
    private func faceLeft(_ duration: TimeInterval) -> CAAnimation {
        let flip = CAKeyframeAnimation(keyPath: "transform.scale.x")
        flip.values = [-1, -1]
        flip.duration = duration
        return flip
    }
}
