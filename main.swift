import AppKit

// Помодоро: большой таймер поверх всех окон и полноэкранных приложений.
let cyclesBeforeLong = 4
// Режимы в минутах: (фокус, короткий перерыв, длинный перерыв)
let modes: [(work: Int, short: Int, long: Int)] = [(25, 5, 15), (45, 10, 20), (60, 15, 25)]

final class AppDelegate: NSObject, NSApplicationDelegate {
    let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 600, height: 320),
        styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
        backing: .buffered, defer: false)
    let phaseLabel = NSTextField(labelWithString: "")
    let timeLabel = NSTextField(labelWithString: "")
    let toggleButton = NSButton(title: "Старт", target: nil, action: nil)
    let modeButton = NSButton(title: "25 мин", target: nil, action: nil)
    var ticker: Timer?

    var phaseIsWork = true
    var breakLong = false
    var completed = 0
    var remaining: TimeInterval = TimeInterval(modes[0].work * 60)
    var modeIndex = 0
    let digitAlpha: CGFloat = 0.85  // непрозрачность цифр таймера: 0 невидимо, 1 сплошные
    var endDate: Date?  // nil = на паузе или не запущен

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel.level = .statusBar  // выше обычных окон и поверх полноэкранных приложений
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false  // тень рисовала бы контур прозрачного окна
        panel.isMovableByWindowBackground = true  // перетаскивать можно за любое место
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.04).cgColor  // почти прозрачная заливка
        container.layer?.cornerRadius = 28
        panel.contentView = container

        phaseLabel.font = .systemFont(ofSize: 26, weight: .semibold)
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 140, weight: .bold)
        timeLabel.textColor = NSColor.white.withAlphaComponent(digitAlpha)
        timeLabel.alignment = .center

        toggleButton.target = self
        toggleButton.action = #selector(toggle)
        modeButton.target = self
        modeButton.action = #selector(cycleMode)
        let skip = NSButton(title: "Дальше", target: self, action: #selector(skipPhase))
        let reset = NSButton(title: "Сброс", target: self, action: #selector(resetPhase))
        let quit = NSButton(title: "Выход", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        let buttons = NSStackView(views: [modeButton, toggleButton, reset, skip, quit])
        buttons.spacing = 10

        let stack = NSStackView(views: [phaseLabel, timeLabel, buttons])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        // Правый верхний угол основного экрана.
        if let frame = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.maxX - 600 - 40, y: frame.maxY - 320 - 40))
        }

        refresh()
        panel.orderFrontRegardless()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func tick() {
        guard let end = endDate else { return }
        let left = end.timeIntervalSinceNow
        if left <= 0 {
            nextPhase(sound: true)
        } else {
            showTime(left)
        }
    }

    @objc func toggle() {
        if let end = endDate {
            remaining = max(0, end.timeIntervalSinceNow)  // пауза
            endDate = nil
        } else {
            endDate = Date().addingTimeInterval(remaining)
        }
        refresh()
    }

    @objc func skipPhase() {
        nextPhase(sound: false)
    }

    @objc func cycleMode() {
        modeIndex = (modeIndex + 1) % modes.count
        phaseIsWork = true
        breakLong = false
        endDate = nil
        remaining = TimeInterval(duration())
        refresh()
    }

    @objc func resetPhase() {
        endDate = nil
        remaining = TimeInterval(duration())
        refresh()
    }

    func duration() -> Int {
        let m = modes[modeIndex]
        if phaseIsWork { return m.work * 60 }
        return (breakLong ? m.long : m.short) * 60
    }

    func nextPhase(sound: Bool) {
        if phaseIsWork {
            completed += 1
            breakLong = completed % cyclesBeforeLong == 0
            phaseIsWork = false
        } else {
            phaseIsWork = true
        }
        endDate = nil
        remaining = TimeInterval(duration())
        if sound {
            NSSound(named: "Glass")?.play()
            panel.orderFrontRegardless()
        }
        refresh()
    }

    func showTime(_ seconds: TimeInterval) {
        let s = max(0, Int(seconds.rounded(.up)))
        timeLabel.stringValue = String(format: "%02d:%02d", s / 60, s % 60)
    }

    func refresh() {
        let color: NSColor
        if phaseIsWork {
            phaseLabel.stringValue = "ФОКУС · готово: \(completed)"
            color = NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.35, alpha: 1)
        } else {
            phaseLabel.stringValue = breakLong ? "ДЛИННЫЙ ПЕРЕРЫВ" : "ПЕРЕРЫВ"
            color = NSColor(calibratedRed: 0.4, green: 0.9, blue: 0.55, alpha: 1)
        }
        phaseLabel.textColor = color
        toggleButton.title = endDate == nil ? "Старт" : "Пауза"
        modeButton.title = "\(modes[modeIndex].work) мин"
        showTime(endDate.map { max(0, $0.timeIntervalSinceNow) } ?? remaining)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // без иконки в Dock
let delegate = AppDelegate()
app.delegate = delegate
app.run()
