import Foundation

struct Preset: Equatable {
    let work: Int  // minutes
    let rest: Int

    static let all = [Preset(work: 25, rest: 5), Preset(work: 50, rest: 10), Preset(work: 15, rest: 3)]
}

@MainActor
enum Settings {
    private static let defaults = UserDefaults.standard

    static var preset: Preset {
        get { Preset.all.first { $0.work == defaults.integer(forKey: "workMinutes") } ?? Preset.all[0] }
        set { defaults.set(newValue.work, forKey: "workMinutes") }
    }

    static var soundOn: Bool {
        get { defaults.object(forKey: "soundOn") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "soundOn") }
    }

    /// Start the next focus round as soon as a break ends.
    static var autoStart: Bool {
        get { defaults.bool(forKey: "autoStart") }
        set { defaults.set(newValue, forKey: "autoStart") }
    }

    /// `--demo` turns every minute into a second, for watching a full cycle quickly.
    static let secondsPerMinute: TimeInterval = CommandLine.arguments.contains("--demo") ? 1 : 60
}

/// Work/break countdown against an absolute end date. The only wakeups are the end of the
/// phase and one label tick per second, and there are none while idle, paused, or the displays sleep.
@MainActor
final class PomodoroTimer: NSObject {
    enum Phase { case idle, work, rest }

    private(set) var phase = Phase.idle
    private(set) var isPaused = false
    private var endDate = Date.distantPast
    private var pausedRemaining: TimeInterval = 0
    private var duration: TimeInterval = 1
    private var endTimer: Timer?
    private var tickTimer: Timer?
    private var ticksEnabled = true

    var onTick: (@MainActor () -> Void)?
    /// Receives the phase that just ran out; the timer is idle again by then.
    var onFinish: (@MainActor (Phase) -> Void)?

    var remaining: TimeInterval { isPaused ? pausedRemaining : max(0, endDate.timeIntervalSinceNow) }
    var seconds: Int { Int(remaining.rounded(.up)) }
    var progress: Double { phase == .idle ? 0 : 1 - remaining / duration }

    func start(_ phase: Phase) {
        let minutes = phase == .work ? Settings.preset.work : Settings.preset.rest
        self.phase = phase
        isPaused = false
        duration = TimeInterval(minutes) * Settings.secondsPerMinute
        endDate = Date(timeIntervalSinceNow: duration)
        arm()
    }

    func togglePause() {
        guard phase != .idle else { return }
        if isPaused {
            isPaused = false
            endDate = Date(timeIntervalSinceNow: pausedRemaining)
            arm()
        } else {
            pausedRemaining = remaining
            isPaused = true
            disarm()
        }
    }

    func reset() {
        phase = .idle
        isPaused = false
        disarm()
    }

    /// Timers don't advance while the Mac sleeps, so re-arm them from the wall clock on wake.
    func resync() {
        if phase != .idle && !isPaused { arm() }
    }

    /// Label ticks are pointless while nobody can see the screen.
    func setTicksEnabled(_ enabled: Bool) {
        ticksEnabled = enabled
        resync()
    }

    private func arm() {
        disarm()
        let end = Timer(fireAt: endDate, interval: 0, target: self, selector: #selector(finish), userInfo: nil, repeats: false)
        end.tolerance = 0.3
        RunLoop.main.add(end, forMode: .common)
        endTimer = end

        onTick?()
        guard ticksEnabled else { return }
        // Fire just after each whole second of the countdown so the label flips on time.
        let firstTick = Date(timeIntervalSinceNow: remaining.truncatingRemainder(dividingBy: 1) + 0.02)
        let tick = Timer(fireAt: firstTick, interval: 1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        tick.tolerance = 0.2
        RunLoop.main.add(tick, forMode: .common)
        tickTimer = tick
    }

    private func disarm() {
        endTimer?.invalidate()
        endTimer = nil
        tickTimer?.invalidate()
        tickTimer = nil
    }

    @objc private func tick() { onTick?() }

    @objc private func finish() {
        guard endDate.timeIntervalSinceNow <= 0.5 else { return arm() }  // the wall clock moved back
        let finished = phase
        reset()
        onFinish?(finished)
    }
}
