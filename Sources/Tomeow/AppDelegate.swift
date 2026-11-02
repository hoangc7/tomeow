import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let timer = PomodoroTimer()
    private var panel: IslandPanel!
    private var island: IslandView!
    /// Focus rounds finished since the last long break.
    private var finishedRounds = 0
    private var longBreakDue: Bool { finishedRounds >= Preset.roundsPerLongBreak }
    /// The progress bar of the menu that is open, kept filling by the timer's ticks.
    private weak var roundsBar: RoundsBar?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let geometry = NotchGeometry.current() else { return NSApp.terminate(nil) }
        island = IslandView(geometry: geometry)
        island.onClick = { [unowned self] in primaryAction() }
        island.onMenu = { [unowned self] in makeMenu() }
        panel = IslandPanel(content: island)
        island.place()
        island.appear()
        panel.orderFrontRegardless()

        timer.onTick = { [unowned self] in refresh() }
        timer.onFinish = { [unowned self] in finished($0) }
        refresh()

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(displaysSlept), name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(displaysWoke), name: NSWorkspace.screensDidWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemWoke), name: NSWorkspace.didWakeNotification, object: nil)
    }

    /// Quitting waits a quarter second while the island tucks back into the notch.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let island else { return .terminateNow }
        // A run-loop timer still fires if terminate was called from a main-queue block, which a
        // dispatched reply would wait behind forever.
        let reply = Timer(timeInterval: island.disappear(), repeats: false) { _ in
            MainActor.assumeIsolated { NSApp.reply(toApplicationShouldTerminate: true) }
        }
        RunLoop.main.add(reply, forMode: .common)
        return .terminateLater
    }

    // MARK: Flow

    private func refresh() {
        island.update(phase: timer.phase, seconds: timer.seconds, progress: timer.progress, paused: timer.isPaused)
        roundsBar?.filled = roundsDone
    }

    /// Finished rounds plus how far the running focus round has got.
    private var roundsDone: Double {
        Double(finishedRounds) + (timer.phase == .work ? timer.progress : 0)
    }

    private func finished(_ phase: PomodoroTimer.Phase) {
        if phase == .rest && longBreakDue { finishedRounds = 0 }  // the cycle is complete
        if phase == .work {
            chime("Purr")
            finishedRounds += 1
            timer.start(.rest, long: longBreakDue)
            island.presentCat(.breakTime, text: longBreakDue ? "Long break time! 😺" : "Short break time! 🐾")
        } else if Settings.autoStart {
            chime("Glass")
            timer.start(.work)
            island.presentCat(.backToWork, text: "Break's over! Focus time 🍅")
        } else {
            chime("Glass")
            island.presentCat(.backToWork, text: "Break's over! Ready? \u{25B6}\u{FE0E}")
        }
        refresh()
    }

    private func primaryAction() {
        switch island.catKind {
        case .backToWork?:
            // The "Ready?" bubble starts the next round; once it has auto-started, a click just sends the cat off.
            if timer.phase == .idle { startWork() } else { island.dismissCat() }
        case .breakTime?: island.dismissCat()
        case nil where timer.phase == .idle: startWork()
        case nil: togglePause()
        }
    }

    private func chime(_ name: String) {
        if Settings.soundOn { NSSound(named: NSSound.Name(name))?.play() }
    }

    @objc private func startWork() {
        island.dismissCat()
        timer.start(.work)
        refresh()
    }

    @objc private func togglePause() {
        timer.togglePause()
        refresh()
    }

    /// Mid-round, drops only the running round; pressed again while idle, also the finished ones.
    /// Skipping a long break completes the cycle.
    @objc private func reset() {
        if timer.phase == .idle || (timer.phase == .rest && longBreakDue) { finishedRounds = 0 }
        island.dismissCat()
        timer.reset()
        refresh()
    }

    // MARK: Menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let bar = RoundsBar(steps: Preset.roundsPerLongBreak)
        bar.filled = roundsDone
        roundsBar = bar
        let barItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        barItem.view = bar
        barItem.isEnabled = false
        menu.addItem(.separator())

        switch (timer.phase, timer.isPaused) {
        case (.idle, _): menu.addItem(item("Start focus", #selector(startWork)))
        case (_, false): menu.addItem(item("Pause", #selector(togglePause)))
        case (_, true): menu.addItem(item("Resume", #selector(togglePause)))
        }
        if timer.phase != .idle {
            menu.addItem(item(timer.phase == .rest ? "Skip break" : "Reset", #selector(reset)))
        } else if finishedRounds > 0 {
            menu.addItem(item("Reset rounds", #selector(reset)))
        }
        menu.addItem(.separator())

        let durations = NSMenu()
        for (index, preset) in Preset.all.enumerated() {
            let title = "Focus \(preset.work) · Break \(preset.rest)/\(preset.longRest)"
            let entry = item(title, #selector(pickPreset(_:)), on: preset == Settings.preset)
            entry.tag = index
            durations.addItem(entry)
        }
        menu.addItem(withTitle: "Durations", action: nil, keyEquivalent: "").submenu = durations
        menu.addItem(item("Auto-start after break", #selector(toggleAutoStart), on: Settings.autoStart))
        menu.addItem(item("Sound", #selector(toggleSound), on: Settings.soundOn))
        menu.addItem(item("Launch at login", #selector(toggleLogin), on: SMAppService.mainApp.status == .enabled))
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit Tomeow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        return menu
    }

    private func item(_ title: String, _ action: Selector, on: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        return item
    }

    /// Takes effect from the next round.
    @objc private func pickPreset(_ sender: NSMenuItem) {
        Settings.preset = Preset.all[sender.tag]
    }

    @objc private func toggleAutoStart() {
        Settings.autoStart.toggle()
    }

    @objc private func toggleSound() {
        Settings.soundOn.toggle()
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSApp.activate()
            NSAlert(error: error).runModal()
        }
    }

    // MARK: System events

    @objc private func screensChanged() {
        if let geometry = NotchGeometry.current() { island.setGeometry(geometry) }
    }

    @objc private func displaysSlept() { timer.setTicksEnabled(false) }
    @objc private func displaysWoke() { timer.setTicksEnabled(true) }
    @objc private func systemWoke() { timer.resync() }
}
