import Cocoa

class PenpotMenuBar: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var mcpStatusMenuItem: NSMenuItem!
    private var timer: Timer?
    private var isStopping = false

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

    // Plugin web server manifest — lightweight GET that closes immediately
    private let mcpHealthURL: URL? = URL(string: "http://localhost:4400/manifest.json")

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

    private func statusDot(_ color: String) -> String {
        switch color {
        case "green":  return "🟢"
        case "yellow": return "🟡"
        case "red":    return "🔴"
        default:       return "⚪"
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if let icon = menuBarIcon {
                button.image = icon
                button.imagePosition = .imageRight
            } else {
                button.title = "◆"
            }
            button.toolTip = "Penpot"
        }

        let menu = NSMenu()

        statusMenuItem = NSMenuItem(title: "\(statusDot("yellow")) Penpot: Starting...", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        mcpStatusMenuItem = NSMenuItem(title: "\(statusDot("yellow")) MCP: Starting...", action: nil, keyEquivalent: "")
        mcpStatusMenuItem.isEnabled = false
        menu.addItem(mcpStatusMenuItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Open Penpot", action: #selector(openPenpot), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Quit Penpot", action: #selector(stopPenpot), keyEquivalent: "q"))

        statusItem.menu = menu

        checkHealth()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.checkHealth()
        }
    }

    private func checkHealth() {
        if let url = healthURL {
            let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                let http = response as? HTTPURLResponse
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                let ok = http?.statusCode == 200 && body.trimmingCharacters(in: .whitespacesAndNewlines) == "OK"
                DispatchQueue.main.async { self?.updateStatus(running: ok) }
            }
            task.resume()
        } else {
            updateStatus(running: false)
        }

        if let url = mcpHealthURL {
            let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                let http = response as? HTTPURLResponse
                let ok = http?.statusCode == 200
                DispatchQueue.main.async { self?.updateMcpStatus(running: ok) }
            }
            task.resume()
        } else {
            updateMcpStatus(running: false)
        }
    }

    private func updateStatus(running: Bool) {
        if isStopping { return }
        if running {
            statusItem.button?.appearsDisabled = false
            statusMenuItem.title = "\(statusDot("green")) Penpot: Running"
        } else {
            statusItem.button?.appearsDisabled = true
            statusMenuItem.title = "\(statusDot("red")) Penpot: Not Running"
        }
    }

    private func updateMcpStatus(running: Bool) {
        if isStopping { return }
        mcpStatusMenuItem.title = running
            ? "\(statusDot("green")) MCP: Running"
            : "\(statusDot("red")) MCP: Not Running"
    }

    @objc private func openPenpot() {
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
        statusMenuItem.title = "\(statusDot("yellow")) Penpot: Stopping..."
        mcpStatusMenuItem.title = "\(statusDot("yellow")) MCP: Stopping..."
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

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = PenpotMenuBar()
app.delegate = delegate
app.run()
