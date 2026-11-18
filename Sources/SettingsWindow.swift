import AppKit

final class SettingsWindow: NSWindowController, NSWindowDelegate {
    private let network = NSComboBox()
    private let offTime = NSTextField(string: "")
    private let retryCount = NSTextField(string: "")
    private let networkStatus = NSTextField(wrappingLabelWithString: "")
    private let networkProgress = NSProgressIndicator()
    private let validation = NSTextField(wrappingLabelWithString: "")
    private let saveSettings: (String, Int, Int) -> Void
    private var scanning = false

    init(networkName: String, offSeconds: Int, retries: Int,
         saveSettings: @escaping (String, Int, Int) -> Void) {
        self.saveSettings = saveSettings
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "WakeUpAuto Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self

        network.stringValue = networkName
        network.placeholderString = "Choose or enter a network"
        offTime.stringValue = String(offSeconds)
        retryCount.stringValue = String(retries)
        for field in [offTime, retryCount] {
            field.alignment = .right
        }

        let labels = ["Wi-Fi Network", "Time Wi-Fi Stays Off (s)", "Retries After First Attempt"]
        let inputs: [NSView] = [network, offTime, retryCount]
        let grid = NSGridView(views: zip(labels, inputs).map { title, field in
            [NSTextField(labelWithString: title), field]
        })
        grid.rowSpacing = 12
        grid.columnSpacing = 16
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading
        network.widthAnchor.constraint(equalToConstant: 240).isActive = true
        for field in [offTime, retryCount] {
            field.widthAnchor.constraint(equalToConstant: 84).isActive = true
        }

        let save = NSButton(title: "Save", target: self, action: #selector(save(_:)))
        save.keyEquivalent = "\r"
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancel, save])
        buttons.spacing = 8
        networkStatus.textColor = .secondaryLabelColor
        networkStatus.maximumNumberOfLines = 2
        networkProgress.style = .spinning
        networkProgress.controlSize = .small
        networkProgress.isDisplayedWhenStopped = false
        networkProgress.isHidden = true
        let networkMessage = NSStackView(views: [networkProgress, networkStatus])
        networkMessage.alignment = .centerY
        networkMessage.spacing = 6
        validation.textColor = .systemRed
        validation.maximumNumberOfLines = 2
        let messages = NSStackView(views: [networkMessage, validation])
        messages.orientation = .vertical
        messages.alignment = .leading
        messages.spacing = 4

        let content = NSView()
        window.contentView = content
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        for view in [icon, grid, messages, buttons] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            icon.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 48),
            icon.heightAnchor.constraint(equalToConstant: 48),
            grid.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 16),
            grid.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            messages.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 12),
            messages.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            messages.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])

        let keyViews: [NSView] = inputs + [cancel, save]
        for (current, next) in zip(keyViews, keyViews.dropFirst() + [network]) {
            current.nextKeyView = next
        }
        window.initialFirstResponder = network
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        showWindow(nil)
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func startNetworkScan() -> Bool {
        guard !scanning else { return false }
        scanning = true
        network.isEnabled = false
        networkStatus.stringValue = "Scanning for Wi-Fi networks…"
        networkProgress.isHidden = false
        networkProgress.startAnimation(nil)
        return true
    }

    func finishNetworkScan(_ names: [String]) {
        scanning = false
        stopNetworkProgress()
        network.isEnabled = true
        network.removeAllItems()
        network.addItems(withObjectValues: names)
        networkStatus.stringValue = names.isEmpty ? "No networks found. You can enter the name manually." : ""
    }

    func showNetworkPermissionStatus(waiting: Bool) {
        stopNetworkProgress()
        network.removeAllItems()
        network.isEnabled = !waiting
        if waiting {
            networkStatus.stringValue = "Waiting for macOS location permission…"
        } else {
            networkStatus.stringValue = "Allow location access to scan for Wi-Fi networks."
        }
    }

    private func stopNetworkProgress() {
        networkProgress.stopAnimation(nil)
        networkProgress.isHidden = true
    }

    func windowWillClose(_ notification: Notification) {
        stopNetworkProgress()
    }

    @objc private func save(_ sender: Any?) {
        window?.makeFirstResponder(nil)
        guard let seconds = Int(offTime.stringValue), (1...60).contains(seconds),
              let retries = Int(retryCount.stringValue), (0...10).contains(retries) else {
            validation.stringValue = "Enter an off time of 1–60 seconds and 0–10 retries."
            return
        }
        saveSettings(network.stringValue, seconds, retries)
        close()
    }

    @objc private func cancel(_ sender: Any?) {
        close()
    }
}
