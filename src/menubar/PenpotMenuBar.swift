import Cocoa

class PenpotMenuBar: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var isStopping = false
    private var popoverLastClosedAt: Date = .distantPast

    private lazy var statsViewController: StatsViewController = {
        let vc = StatsViewController()
        vc.onOpenPenpot = { [weak self] in self?.openPenpotURL() }
        return vc
    }()

    private lazy var popover: NSPopover = {
        let p = NSPopover()
        p.contentViewController = statsViewController
        p.behavior = .transient
        p.delegate = self
        return p
    }()

    private let scriptPath: String = {
        let bundle = Bundle.main.executableURL?.deletingLastPathComponent()
        return bundle?.appendingPathComponent("Penpot").path ?? ""
    }()

    private let healthURL: URL? = {
        let envPath = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent(".env").path ?? ""
        var baseURL = "http://localhost:9001"
        if let contents = try? String(contentsOfFile: envPath, encoding: .utf8) {
            for line in contents.split(separator: "\n") {
                if line.hasPrefix("PENPOT_PUBLIC_URI=") {
                    baseURL = String(line.dropFirst("PENPOT_PUBLIC_URI=".count))
                    break
                }
            }
        }
        return URL(string: "\(baseURL)/readyz")
    }()

    private let mcpHealthURL: URL? = URL(string: "http://localhost:4400/manifest.json")

    // "Penpot Desktop 2.17.1.1 · Penpot 2.17.1", from Info.plist (stamped by
    // `make assemble`) and the pinned .version next to the executable.
    private let versionLabel: String = {
        let macOS = Bundle.main.executableURL?.deletingLastPathComponent()
        let plist = macOS?.deletingLastPathComponent().appendingPathComponent("Info.plist")
        let info = plist.flatMap { NSDictionary(contentsOf: $0) }
        let app = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let penpot = macOS
            .flatMap { try? String(contentsOf: $0.appendingPathComponent(".version"), encoding: .utf8) }?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        return "Penpot Desktop \(app) · Penpot \(penpot)"
    }()

    private lazy var menuBarIcon: NSImage? = {
        let dir = Bundle.main.executableURL?.deletingLastPathComponent()
        let retinaPath = dir?.deletingLastPathComponent()
            .appendingPathComponent("Resources/MenuBarIconTemplate@2x.png").path
        let normalPath = dir?.deletingLastPathComponent()
            .appendingPathComponent("Resources/MenuBarIconTemplate.png").path
        let imagePath = retinaPath ?? normalPath ?? ""
        guard let image = NSImage(contentsOfFile: imagePath) else { return nil }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if let icon = menuBarIcon {
                button.image = icon
                button.imagePosition = .imageRight
            } else {
                button.title = "◆"
            }
            button.toolTip = versionLabel
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseDown])
        }

        // Pre-load the stats VC so polling starts before the user opens the popover
        statsViewController.loadViewIfNeeded()

        checkHealth()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.checkHealth()
        }
    }

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseDown {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            let elapsed = Date().timeIntervalSince(popoverLastClosedAt)
            guard elapsed > 0.1 else { return }
            checkHealth()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let version = NSMenuItem(title: versionLabel, action: nil, keyEquivalent: "")
        version.isEnabled = false
        menu.addItem(version)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Penpot", action: #selector(openPenpot), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Penpot", action: #selector(stopPenpot), keyEquivalent: ""))

        for item in menu.items { item.target = self }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        popoverLastClosedAt = Date()
    }

    // MARK: - Health

    private func checkHealth() {
        if let url = healthURL {
            let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
                let http = response as? HTTPURLResponse
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                let ok = http?.statusCode == 200 && body.trimmingCharacters(in: .whitespacesAndNewlines) == "OK"
                DispatchQueue.main.async {
                    self?.statusItem.button?.appearsDisabled = !ok
                    self?.statsViewController.updatePenpotStatus(running: ok)
                }
            }
            task.resume()
        } else {
            statsViewController.updatePenpotStatus(running: false)
        }

        if let url = mcpHealthURL {
            let task = URLSession.shared.dataTask(with: url) { [weak self] _, response, _ in
                let ok = (response as? HTTPURLResponse)?.statusCode == 200
                DispatchQueue.main.async { self?.statsViewController.updateMcpStatus(running: ok) }
            }
            task.resume()
        } else {
            statsViewController.updateMcpStatus(running: false)
        }
    }

    // MARK: - Actions

    @objc private func openPenpot() { openPenpotURL() }

    private func openPenpotURL() {
        let envPath = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent(".env").path ?? ""
        var baseURL = "http://localhost:9001"
        if let contents = try? String(contentsOfFile: envPath, encoding: .utf8) {
            for line in contents.split(separator: "\n") {
                if line.hasPrefix("PENPOT_PUBLIC_URI=") {
                    baseURL = String(line.dropFirst("PENPOT_PUBLIC_URI=".count))
                    break
                }
            }
        }
        if let url = URL(string: baseURL) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func stopPenpot() {
        isStopping = true
        popover.performClose(nil)
        DispatchQueue.global().async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self?.scriptPath ?? "")
            process.arguments = ["stop"]
            try? process.run()
            process.waitUntilExit()
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

}
