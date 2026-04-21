import Cocoa

class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class OverlayView: NSView {
    var onDismiss: (() -> Void)?

    override var acceptsFirstResponder: Bool { return true }

    override func mouseDown(with event: NSEvent) {
        onDismiss?()
    }

    override func keyDown(with event: NSEvent) {
        let key = event.keyCode
        // 53 = Escape, 49 = Space, 36 = Return, 76 = KeypadEnter
        if key == 53 || key == 49 || key == 36 || key == 76 {
            onDismiss?()
            return
        }
        // Cmd+Q
        if event.modifierFlags.contains(.command), let chars = event.charactersIgnoringModifiers, chars == "q" {
            NSApp.terminate(nil)
            return
        }
        super.keyDown(with: event)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var overlayWindow: NSWindow?
    var overlayAutoCloseTimer: Timer?
    var overlayCountdownTimer: Timer?
    var overlayCountdownLabel: NSTextField?
    var overlayRemainingSeconds: Int = 20
    var intervalMinutes: Double = 20
    var remainingSeconds: Int = 0
    var menuTickTimer: Timer?
    var isPaused = false
    var screenLockTime: Date?

    // How long the break overlay stays on screen if you don't skip
    let breakDurationSeconds: Int = 20

    // If screen is locked for at least this long, reset the break timer on unlock
    let lockResetThresholdSeconds: TimeInterval = 5 * 60

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarIcon()
        buildMenu()
        startTimer()
        registerScreenLockObservers()
    }

    func registerScreenLockObservers() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(
            self,
            selector: #selector(screenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        dnc.addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }

    @objc func screenLocked() {
        screenLockTime = Date()
    }

    @objc func screenUnlocked() {
        defer { screenLockTime = nil }
        guard let lockTime = screenLockTime else { return }
        let lockDuration = Date().timeIntervalSince(lockTime)
        if lockDuration >= lockResetThresholdSeconds {
            // Treated as a real break — reset the countdown
            startTimer()
            buildMenu()
        }
    }

    func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }
        if isPaused {
            button.title = "⏸ Break"
            return
        }
        let mins = max(0, remainingSeconds) / 60
        let secs = max(0, remainingSeconds) % 60
        button.title = String(format: "☕ %d:%02d", mins, secs)
    }

    func buildMenu() {
        let menu = NSMenu()

        let timerItem = NSMenuItem(title: timerStatusText(), action: nil, keyEquivalent: "")
        timerItem.tag = 100
        menu.addItem(timerItem)

        menu.addItem(NSMenuItem.separator())

        let pauseTitle = isPaused ? "Resume" : "Pause"
        menu.addItem(NSMenuItem(title: pauseTitle, action: #selector(togglePause), keyEquivalent: "p"))

        menu.addItem(NSMenuItem(title: "Take Break Now", action: #selector(showOverlayNow), keyEquivalent: "b"))
        menu.addItem(NSMenuItem(title: "Reset Timer", action: #selector(resetTimer), keyEquivalent: "r"))

        menu.addItem(NSMenuItem.separator())

        let intervalMenu = NSMenu()
        for mins in [5, 10, 15, 20, 30, 45, 60] {
            let item = NSMenuItem(title: "\(mins) minutes", action: #selector(changeInterval(_:)), keyEquivalent: "")
            item.tag = mins
            item.representedObject = mins
            if Double(mins) == intervalMinutes {
                item.state = .on
            }
            intervalMenu.addItem(item)
        }
        let intervalItem = NSMenuItem(title: "Interval", action: nil, keyEquivalent: "")
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    func timerStatusText() -> String {
        if isPaused {
            return "Paused"
        }
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "Next break in %d:%02d", mins, secs)
    }

    func startTimer() {
        remainingSeconds = Int(intervalMinutes * 60)
        isPaused = false
        updateMenuBarIcon()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            self.remainingSeconds -= 1
            self.updateMenuBarIcon()
            self.updateTimerMenuItem()
            if self.remainingSeconds <= 0 {
                self.showOverlay()
            }
        }
        updateMenuBarIcon()
    }

    func updateTimerMenuItem() {
        if let menu = statusItem.menu, let item = menu.item(withTag: 100) {
            item.title = timerStatusText()
        }
    }

    @objc func togglePause() {
        isPaused.toggle()
        if !isPaused {
            // Resume: keep existing remainingSeconds so you pick up where you left off
        }
        updateMenuBarIcon()
        buildMenu()
    }

    @objc func showOverlayNow() {
        showOverlay()
    }

    @objc func resetTimer() {
        startTimer()
        buildMenu()
    }

    @objc func changeInterval(_ sender: NSMenuItem) {
        if let mins = sender.representedObject as? Int {
            intervalMinutes = Double(mins)
            startTimer()
            buildMenu()
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func showOverlay() {
        timer?.invalidate()

        // Prevent multiple overlays
        if overlayWindow != nil { return }

        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let window = OverlayWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .statusBar + 1
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false

        let contentView = OverlayView(frame: frame)
        contentView.onDismiss = { [weak self] in
            self?.dismissOverlay()
        }

        let dimView = NSView(frame: frame)
        dimView.wantsLayer = true
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.88).cgColor
        contentView.addSubview(dimView)

        let containerWidth: CGFloat = 600
        let containerX = (frame.width - containerWidth) / 2
        let centerY = frame.height / 2

        // Emoji
        let emojiLabel = makeLabel(
            frame: NSRect(x: containerX, y: centerY + 120, width: containerWidth, height: 80),
            text: "👀",
            fontSize: 64,
            color: .white
        )
        contentView.addSubview(emojiLabel)

        // Title
        let titleLabel = makeLabel(
            frame: NSRect(x: containerX, y: centerY + 60, width: containerWidth, height: 50),
            text: "Time for a Break!",
            fontSize: 40,
            color: .white,
            weight: .bold
        )
        contentView.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = makeLabel(
            frame: NSRect(x: containerX, y: centerY + 20, width: containerWidth, height: 30),
            text: "Rest your eyes. Stand up. Stretch.",
            fontSize: 20,
            color: NSColor.white.withAlphaComponent(0.8)
        )
        contentView.addSubview(subtitleLabel)

        // Countdown
        overlayRemainingSeconds = breakDurationSeconds
        let countdownLabel = makeLabel(
            frame: NSRect(x: containerX, y: centerY - 40, width: containerWidth, height: 40),
            text: "Auto-closes in \(breakDurationSeconds)s",
            fontSize: 18,
            color: NSColor.white.withAlphaComponent(0.6)
        )
        contentView.addSubview(countdownLabel)
        overlayCountdownLabel = countdownLabel

        // Big Skip button
        let btnWidth: CGFloat = 280
        let btnHeight: CGFloat = 64
        let skipButton = NSButton(frame: NSRect(
            x: (frame.width - btnWidth) / 2,
            y: centerY - 140,
            width: btnWidth,
            height: btnHeight
        ))
        skipButton.title = "Skip  (Esc / Space / Click)"
        skipButton.bezelStyle = .regularSquare
        skipButton.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        skipButton.wantsLayer = true
        skipButton.layer?.backgroundColor = NSColor.systemRed.cgColor
        skipButton.layer?.cornerRadius = 12
        skipButton.contentTintColor = .white
        skipButton.isBordered = false
        skipButton.target = self
        skipButton.action = #selector(dismissOverlay)
        contentView.addSubview(skipButton)

        // Hint text
        let hintLabel = makeLabel(
            frame: NSRect(x: containerX, y: centerY - 200, width: containerWidth, height: 24),
            text: "Press Escape, Space, Enter, or click anywhere to skip",
            fontSize: 14,
            color: NSColor.white.withAlphaComponent(0.5)
        )
        contentView.addSubview(hintLabel)

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(contentView)
        NSApp.activate(ignoringOtherApps: true)

        overlayWindow = window

        // Safety: countdown auto-close
        overlayCountdownTimer?.invalidate()
        overlayCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.overlayRemainingSeconds -= 1
            if self.overlayRemainingSeconds <= 0 {
                self.dismissOverlay()
            } else {
                self.overlayCountdownLabel?.stringValue = "Auto-closes in \(self.overlayRemainingSeconds)s"
            }
        }
    }

    func makeLabel(frame: NSRect, text: String, fontSize: CGFloat, color: NSColor, weight: NSFont.Weight = .regular) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.stringValue = text
        label.font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        label.alignment = .center
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.textColor = color
        return label
    }

    @objc func dismissOverlay() {
        overlayCountdownTimer?.invalidate()
        overlayCountdownTimer = nil
        overlayCountdownLabel = nil
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        startTimer()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
