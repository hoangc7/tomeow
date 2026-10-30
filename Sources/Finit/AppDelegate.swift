import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let timer = PomodoroTimer()
    private var panel: IslandPanel!
    private var island: IslandView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let geometry = NotchGeometry.current() else { return NSApp.terminate(nil) }
        island = IslandView(geometry: geometry)
        island.onClick = { [unowned self] in primaryAction() }
        island.onMenu = { [unowned self] in makeMenu() }
        panel = IslandPanel(content: island)
        island.place()
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

    // MARK: Flow

    private func refresh() {
        island.update(phase: timer.phase, seconds: timer.seconds, progress: timer.progress, paused: timer.isPaused)
    }

    private func finished(_ phase: PomodoroTimer.Phase) {
        if phase == .work {
            chime("Purr")
            timer.start(.rest)
            island.presentCat(.breakTime, text: "Short break time! 🐾")
        } else {
            chime("Glass")
            island.presentCat(.backToWork, text: "Break's over! Ready? \u{25B6}\u{FE0E}")
        }
        refresh()
    }

    private func primaryAction() {
        switch island.catKind {
        case .backToWork?: startWork()  // the bubble asks "Ready?"
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

    @objc private func reset() {
        island.dismissCat()
        timer.reset()
        refresh()
    }

    // MARK: Menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        switch (timer.phase, timer.isPaused) {
        case (.idle, _): menu.addItem(item("Start Focus", #selector(startWork)))
        case (_, false): menu.addItem(item("Pause", #selector(togglePause)))
        case (_, true): menu.addItem(item("Resume", #selector(togglePause)))
        }
        if timer.phase != .idle {
            menu.addItem(item(timer.phase == .rest ? "Skip Break" : "Reset", #selector(reset)))
        }
        menu.addItem(.separator())

        let durations = NSMenu()
        for (index, preset) in Preset.all.enumerated() {
            let entry = item("\(preset.work) min focus · \(preset.rest) min break", #selector(pickPreset(_:)),
                             on: preset == Settings.preset)
            entry.tag = index
            durations.addItem(entry)
        }
        menu.addItem(withTitle: "Durations", action: nil, keyEquivalent: "").submenu = durations
        menu.addItem(item("Sound", #selector(toggleSound), on: Settings.soundOn))
        menu.addItem(item("Launch at Login", #selector(toggleLogin), on: SMAppService.mainApp.status == .enabled))
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit Finit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
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
