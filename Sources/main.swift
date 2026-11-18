import AppKit
import CoreLocation
import CoreWLAN
import IOKit
import ServiceManagement

private let defaults = UserDefaults.standard
private let wakeWarning = "Wi-Fi recovery failed. Turn Wi-Fi off and back on manually."

private struct Settings {
    let network = defaults.string(forKey: "network") ?? ""
    let offSeconds = defaults.integer(forKey: "offSeconds")
    let retries = defaults.integer(forKey: "retries")
}

private enum Diagnostics {
    static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/WakeUpAuto", isDirectory: true)
    static let file = directory.appendingPathComponent("WakeUpAuto.txt")
    private static let lock = NSLock()

    static func write(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        do {
            let fm = FileManager.default
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            if !fm.fileExists(atPath: file.path) {
                try Data().write(to: file)
            }
            let stream = try FileHandle(forWritingTo: file)
            defer { try? stream.close() }
            let length = try stream.seekToEnd()
            if length > 1_000_000 {
                try stream.truncate(atOffset: 0)
                try stream.seek(toOffset: 0)
            }
            let date = Date().formatted(.iso8601)
            try stream.write(contentsOf: Data("\(date)  \(message)\n".utf8))
        } catch {
            NSLog("WakeUpAuto: could not write to the log (%@)", String(describing: error))
        }
    }
}

private func powerProperty(_ key: String) -> Any? {
    let domain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    guard domain != IO_OBJECT_NULL else { return nil }
    defer { IOObjectRelease(domain) }
    return IORegistryEntryCreateCFProperty(domain, key as CFString, kCFAllocatorDefault, 0)?
        .takeRetainedValue()
}

private final class WakeUpAuto: NSObject, NSApplicationDelegate, NSMenuDelegate, CLLocationManagerDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let worker = DispatchQueue(label: "it.siriokds.WakeUpAuto.wifi")
    private let location = CLLocationManager()
    private var settingsWindow: SettingsWindow?
    private var sleepInstant: ContinuousClock.Instant?
    private var generation = 0
    private var scheduledWake: Int?
    private var busy = false
    private var result = "Waiting for wake"
    private var warning = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["offSeconds": 3, "retries": 3])
        menu.delegate = self
        location.delegate = self
        statusItem.menu = menu
        refreshIcon()
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        Diagnostics.write("WakeUpAuto \(version) started · waiting for a lid-open wake")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let preferences = menu.addItem(withTitle: "Settings…", action: #selector(configure), keyEquivalent: ",")
        preferences.target = self
        let login = menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        let diagnostics = NSMenu()
        diagnostics.addItem(withTitle: warning ? wakeWarning : result, action: nil, keyEquivalent: "")
        let openLog = diagnostics.addItem(withTitle: "Open Log…", action: #selector(showLog), keyEquivalent: "")
        openLog.target = self
        menu.addItem(withTitle: "Diagnostics", action: nil, keyEquivalent: "").submenu = diagnostics
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit WakeUpAuto", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        busy ? .terminateCancel : .terminateNow
    }

    private func refreshIcon() {
        statusItem.button?.image = StatusIcon.make(warning: warning)
        statusItem.button?.setAccessibilityLabel(warning ? wakeWarning : "WakeUpAuto")
        statusItem.button?.toolTip = warning ? wakeWarning : result
    }

    @objc private func configure() {
        if let settingsWindow, settingsWindow.window?.isVisible == true {
            settingsWindow.show()
            return
        }
        let settings = Settings()
        let window = SettingsWindow(networkName: settings.network, offSeconds: settings.offSeconds,
                                    retries: settings.retries) { network, offSeconds, retries in
            defaults.set(network, forKey: "network")
            defaults.set(offSeconds, forKey: "offSeconds")
            defaults.set(retries, forKey: "retries")
        }
        settingsWindow = window
        window.show()
        loadNetworks()
        if location.authorizationStatus == .notDetermined {
            location.requestAlwaysAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        loadNetworks()
    }

    private func loadNetworks() {
        guard let window = settingsWindow, window.window?.isVisible == true else { return }
        guard location.authorizationStatus == .authorizedAlways else {
            window.showNetworkPermissionStatus(waiting: location.authorizationStatus == .notDetermined)
            return
        }
        guard window.startNetworkScan() else { return }
        worker.async { [weak self, weak window] in
            let wifi = CWWiFiClient.shared().interface()
            let scanned = (try? wifi?.scanForNetworks(withName: nil)) ?? []
            var names = Set(scanned.compactMap(\.ssid))
            if let current = wifi?.ssid() { names.insert(current) }
            let sorted = names.sorted()
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window else { return }
                let authorized = self.location.authorizationStatus == .authorizedAlways
                window.finishNetworkScan(authorized ? sorted : [])
                if !authorized {
                    window.showNetworkPermissionStatus(waiting: false)
                }
            }
        }
    }

    @objc private func toggleLogin() {
        do {
            let service = SMAppService.mainApp
            if service.status == .enabled { try service.unregister() }
            else { try service.register() }
        } catch {
            present("Could Not Update Launch at Login", error.localizedDescription)
        }
    }

    @objc private func showLog() {
        if !NSWorkspace.shared.open(Diagnostics.file) {
            present("Could Not Open Log", Diagnostics.file.path)
        }
    }

    private func present(_ title: String, _ details: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = details
        NSApp.activate()
        alert.runModal()
    }

    @objc private func willSleep() {
        generation += 1
        sleepInstant = .now
        Diagnostics.write("Sleep")
    }

    @objc private func didWake() {
        let duration = sleepInstant.map { "\($0.duration(to: .now).components.seconds) s" } ?? "unavailable"
        sleepInstant = nil
        let reason = powerProperty("Wake Reason") as? String ?? "unavailable"
        Diagnostics.write("Wake · sleep duration: \(duration) · reason: \(reason)")
        let lidWake = reason.lowercased().split(whereSeparator: { !$0.isLetter })
            .contains { ["lid", "lidopen", "clamshellopen"].contains($0) }
        guard lidWake else {
            Diagnostics.write("Check skipped · wake was not triggered by opening the lid")
            return
        }
        guard scheduledWake != generation else { return }
        guard !busy else {
            Diagnostics.write("Check skipped · another check is already running")
            return
        }
        let wake = generation
        scheduledWake = wake
        Diagnostics.write("Lid-open wake detected · waiting 5 s before checking")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [self] in
            guard generation == wake, sleepInstant == nil else {
                Diagnostics.write("Check skipped · Mac went back to sleep")
                return
            }
            guard powerProperty("AppleClamshellState") as? Bool == false else {
                Diagnostics.write("Check skipped · could not confirm that the lid is open")
                return
            }
            beginWiFiCheck()
        }
    }

    private func beginWiFiCheck() {
        guard !busy else { return }
        let settings = Settings()
        guard !settings.network.isEmpty else {
            Diagnostics.write("Check skipped · no Wi-Fi network selected")
            return
        }
        guard location.authorizationStatus == .authorizedAlways else {
            result = "Allow location access to identify the Wi-Fi network"
            refreshIcon()
            Diagnostics.write("Check skipped · location access not granted")
            return
        }
        busy = true
        result = "Checking Wi-Fi…"
        refreshIcon()
        Diagnostics.write("Starting Wi-Fi check")
        worker.async {
            let outcome = Self.recover(settings)
            DispatchQueue.main.async { self.finish(outcome) }
        }
    }

    private enum Outcome { case healthy, skipped, failed }

    private static func recover(_ settings: Settings) -> Outcome {
        guard let interface = CWWiFiClient.shared().interface() else {
            Diagnostics.write("Wi-Fi interface unavailable")
            return .skipped
        }
        do {
            switch try WiFi.check(interface, network: settings.network) {
            case .healthy: return .healthy
            case .outsideNetwork: return .skipped
            case .failed: Diagnostics.write("Initial check failed")
            }
        } catch {
            Diagnostics.write("Could not run the initial check · error \((error as NSError).code)")
            return .skipped
        }
        for attempt in 1...(settings.retries + 1) {
            Diagnostics.write("Attempt \(attempt)/\(settings.retries + 1) · turning Wi-Fi off")
            do {
                if interface.powerOn() { try interface.setPower(false) }
                Diagnostics.write("Waiting · \(settings.offSeconds) s")
                Thread.sleep(forTimeInterval: TimeInterval(settings.offSeconds))
                Diagnostics.write("Turning Wi-Fi back on")
                try interface.setPower(true)
            } catch {
                Diagnostics.write("Could not change Wi-Fi power state · error \((error as NSError).code)")
                continue
            }
            Thread.sleep(forTimeInterval: 5)
            do {
                if try WiFi.check(interface, network: settings.network) == .healthy {
                    Diagnostics.write("Check passed after turning Wi-Fi back on")
                    return .healthy
                }
                Diagnostics.write("Check failed after turning Wi-Fi back on")
                if let current = interface.ssid(), current != settings.network { return .skipped }
            } catch {
                Diagnostics.write("Check failed after turning Wi-Fi back on · error \((error as NSError).code)")
            }
        }
        return .failed
    }

    private func finish(_ outcome: Outcome) {
        busy = false
        switch outcome {
        case .healthy:
            warning = false
            result = "Last Wi-Fi check passed"
        case .skipped:
            result = "Wi-Fi check skipped"
        case .failed:
            warning = true
            result = wakeWarning
        }
        refreshIcon()
        Diagnostics.write("Result · \(result)")
    }
}

let app = NSApplication.shared
private let delegate = WakeUpAuto()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
