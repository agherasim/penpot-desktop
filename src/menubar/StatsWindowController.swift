import Cocoa

// MARK: - Container card

class ContainerCardView: NSView {
    private let nameLabel = NSTextField(labelWithString: "")
    private let cpuSpark  = SparklineView()
    private let memSpark  = SparklineView()
    private let cpuValue  = NSTextField(labelWithString: "--")
    private let memValue  = NSTextField(labelWithString: "--")
    private let netValue  = NSTextField(labelWithString: "--")

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        updateLayerColors()
        buildLayout()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateLayerColors()
    }

    private func updateLayerColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.borderColor     = NSColor.separatorColor.cgColor
        }
    }

    private func tag(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        f.textColor = .tertiaryLabelColor
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }

    private func buildLayout() {
        nameLabel.font = .boldSystemFont(ofSize: 12)
        nameLabel.textColor = .labelColor

        cpuSpark.lineColor = .systemBlue
        cpuSpark.fixedMax  = nil
        memSpark.lineColor = .systemGreen
        memSpark.fixedMax  = 100

        for v in [cpuValue, memValue, netValue] {
            v.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            v.textColor = .secondaryLabelColor
            v.alignment = .right
        }

        let cpuTag = tag("CPU")
        let memTag = tag("MEM")
        let netTag = tag("NET")

        let views: [NSView] = [nameLabel, cpuSpark, memSpark,
                               cpuValue, memValue, netValue,
                               cpuTag, memTag, netTag]
        views.forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }

        let pad: CGFloat  = 12
        let tagW: CGFloat = 34

        NSLayoutConstraint.activate([
            // Name
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: pad),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),

            // CPU spark — full width, value below
            cpuTag.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            cpuTag.widthAnchor.constraint(equalToConstant: tagW),
            cpuTag.centerYAnchor.constraint(equalTo: cpuSpark.centerYAnchor),

            cpuSpark.leadingAnchor.constraint(equalTo: cpuTag.trailingAnchor, constant: 8),
            cpuSpark.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
            cpuSpark.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),

            cpuValue.leadingAnchor.constraint(equalTo: cpuSpark.leadingAnchor),
            cpuValue.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
            cpuValue.topAnchor.constraint(equalTo: cpuSpark.bottomAnchor, constant: 2),

            // MEM spark — full width, value below
            memTag.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            memTag.widthAnchor.constraint(equalToConstant: tagW),
            memTag.centerYAnchor.constraint(equalTo: memSpark.centerYAnchor),

            memSpark.leadingAnchor.constraint(equalTo: memTag.trailingAnchor, constant: 8),
            memSpark.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
            memSpark.topAnchor.constraint(equalTo: cpuValue.bottomAnchor, constant: 8),

            memValue.leadingAnchor.constraint(equalTo: memSpark.leadingAnchor),
            memValue.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
            memValue.topAnchor.constraint(equalTo: memSpark.bottomAnchor, constant: 2),

            // NET — tag + value on one line
            netTag.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            netTag.widthAnchor.constraint(equalToConstant: tagW),
            netTag.centerYAnchor.constraint(equalTo: netValue.centerYAnchor),

            netValue.leadingAnchor.constraint(equalTo: netTag.trailingAnchor, constant: 8),
            netValue.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
            netValue.topAnchor.constraint(equalTo: memValue.bottomAnchor, constant: 8),
            netValue.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -pad),
        ])
    }

    func update(stat: ContainerStats, history: [(cpu: Double, mem: Double)]) {
        nameLabel.stringValue = stat.name
        cpuSpark.values = history.map { $0.cpu }
        memSpark.values = history.map { $0.mem }
        cpuValue.stringValue = String(format: "%.1f%%", stat.cpuPercent)
        memValue.stringValue = "\(fmtBytes(stat.memUsedBytes)) / \(fmtBytes(stat.memLimitBytes)) (\(Int(stat.memPercent))%)"
        netValue.stringValue = "▲ \(fmtBytes(stat.netInBytes))  ▼ \(fmtBytes(stat.netOutBytes))"
    }

    private func fmtBytes(_ b: Double) -> String {
        switch b {
        case 1e9...:  return String(format: "%.1f GB", b / 1e9)
        case 1e6...:  return String(format: "%.0f MB", b / 1e6)
        case 1e3...:  return String(format: "%.0f KB", b / 1e3)
        default:      return String(format: "%.0f B",  b)
        }
    }
}

// MARK: - Stats view controller

class StatsViewController: NSViewController {
    var onOpenPenpot:  (() -> Void)?
    var onStopCluster: (() -> Void)?

    private let penpotStatusLabel = NSTextField(labelWithString: "⚪ Penpot: Checking…")
    private let mcpStatusLabel    = NSTextField(labelWithString: "⚪ MCP: Checking…")
    private var outerHStack:      NSStackView!
    private var columnStacks:     [NSStackView] = []
    private var cardViews:        [String: ContainerCardView] = [:]
    private var widthConstraints: [String: NSLayoutConstraint] = [:]
    private var history:          [String: [(cpu: Double, mem: Double)]] = [:]
    private var pollTimer:    Timer?
    private var isPolling     = false
    private let maxHistory    = 30
    private let dockerPaths   = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        "/Applications/Docker.app/Contents/Resources/bin/docker",
        NSString("~/.docker/bin/docker").expandingTildeInPath,
        "/usr/bin/docker",
    ]

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = NSSize(width: 440, height: 520)
        buildLayout()
        startPolling()
    }

    func updatePenpotStatus(running: Bool) {
        penpotStatusLabel.stringValue = running ? "🟢 Penpot: Running" : "🔴 Penpot: Not Running"
    }

    func updateMcpStatus(running: Bool) {
        mcpStatusLabel.stringValue = running ? "🟢 MCP: Running" : "🔴 MCP: Not Running"
    }

    // MARK: - Layout

    private func buildLayout() {
        let header = makeHeader()
        let topDiv = makeDivider()
        let scroll = makeScrollView()
        let botDiv = makeDivider()
        let footer = makeFooter()

        for v in [header, topDiv, scroll, botDiv, footer] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 44),

            topDiv.topAnchor.constraint(equalTo: header.bottomAnchor),
            topDiv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topDiv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topDiv.heightAnchor.constraint(equalToConstant: 1),

            scroll.topAnchor.constraint(equalTo: topDiv.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: botDiv.topAnchor),

            botDiv.bottomAnchor.constraint(equalTo: footer.topAnchor),
            botDiv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            botDiv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            botDiv.heightAnchor.constraint(equalToConstant: 1),

            footer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footer.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    private func makeHeader() -> NSView {
        let v = NSView()

        penpotStatusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        penpotStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        mcpStatusLabel.font = .systemFont(ofSize: 12)
        mcpStatusLabel.textColor = .secondaryLabelColor
        mcpStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        v.addSubview(penpotStatusLabel)
        v.addSubview(mcpStatusLabel)

        NSLayoutConstraint.activate([
            penpotStatusLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            penpotStatusLabel.centerYAnchor.constraint(equalTo: v.centerYAnchor),

            mcpStatusLabel.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -16),
            mcpStatusLabel.centerYAnchor.constraint(equalTo: v.centerYAnchor),
        ])

        return v
    }

    private func makeDivider() -> NSBox {
        let b = NSBox()
        b.boxType = .separator
        return b
    }

    private func makeScrollView() -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground     = false

        outerHStack = NSStackView()
        outerHStack.orientation  = .horizontal
        outerHStack.alignment    = .top
        outerHStack.spacing      = 10
        outerHStack.distribution = .fillEqually
        outerHStack.edgeInsets   = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        outerHStack.translatesAutoresizingMaskIntoConstraints = false

        scroll.documentView = outerHStack

        let clip = scroll.contentView
        NSLayoutConstraint.activate([
            outerHStack.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            outerHStack.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
            outerHStack.topAnchor.constraint(equalTo: clip.topAnchor),
        ])

        return scroll
    }

    private func makeColumnStack() -> NSStackView {
        let col = NSStackView()
        col.orientation = .vertical
        col.spacing     = 10
        col.translatesAutoresizingMaskIntoConstraints = false
        return col
    }

    private func makeFooter() -> NSView {
        let v = NSView()

        let openBtn = NSButton(title: "Open Penpot ↗", target: self, action: #selector(openTapped))
        openBtn.bezelStyle = .rounded
        openBtn.translatesAutoresizingMaskIntoConstraints = false

        let stopBtn = NSButton(title: "Stop Penpot", target: self, action: #selector(stopTapped))
        stopBtn.bezelStyle = .rounded
        stopBtn.contentTintColor = .systemRed
        stopBtn.translatesAutoresizingMaskIntoConstraints = false

        v.addSubview(openBtn)
        v.addSubview(stopBtn)

        NSLayoutConstraint.activate([
            openBtn.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            openBtn.centerYAnchor.constraint(equalTo: v.centerYAnchor),

            stopBtn.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -16),
            stopBtn.centerYAnchor.constraint(equalTo: v.centerYAnchor),
        ])

        return v
    }

    @objc private func openTapped() { onOpenPenpot?() }
    @objc private func stopTapped() { onStopCluster?() }

    // MARK: - Polling

    private func startPolling() {
        guard pollTimer == nil else { return }
        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        guard !isPolling else { return }
        guard let docker = dockerPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }
        isPolling = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let stats = self.runDockerStats(docker: docker)
            DispatchQueue.main.async {
                self.applyStats(stats)
                self.isPolling = false
            }
        }
    }

    private func runDockerStats(docker: String) -> [ContainerStats] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: docker)
        proc.arguments     = ["stats", "--no-stream", "--format", "{{json .}}"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = Pipe()
        guard (try? proc.run()) != nil else { return [] }
        proc.waitUntilExit()
        let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return raw.split(separator: "\n")
            .compactMap { DockerStatsParser.parse(String($0)) }
            .filter { $0.name.hasPrefix(DockerStatsParser.containerPrefix) }
    }

    private func applyStats(_ stats: [ContainerStats]) {
        let incoming = Set(stats.map { $0.name })
        for name in Set(cardViews.keys).subtracting(incoming) {
            widthConstraints[name]?.isActive = false
            widthConstraints.removeValue(forKey: name)
            cardViews[name]?.removeFromSuperview()
            cardViews.removeValue(forKey: name)
            history.removeValue(forKey: name)
        }

        let sorted     = stats.sorted(by: { $0.name < $1.name })
        let targetCols = sorted.count > 3 ? 2 : 1

        if targetCols != columnStacks.count {
            for wc in widthConstraints.values { wc.isActive = false }
            widthConstraints = [:]
            for card in cardViews.values { card.removeFromSuperview() }
            for cs in columnStacks { outerHStack.removeArrangedSubview(cs); cs.removeFromSuperview() }

            columnStacks = (0..<targetCols).map { _ in
                let col = makeColumnStack()
                outerHStack.addArrangedSubview(col)
                return col
            }

            preferredContentSize = NSSize(width: targetCols == 1 ? 440 : 860, height: 520)
        }

        for (i, stat) in sorted.enumerated() {
            var h = history[stat.name] ?? []
            h.append((stat.cpuPercent, stat.memPercent))
            if h.count > maxHistory { h.removeFirst() }
            history[stat.name] = h

            let col = columnStacks[i % targetCols]

            let card: ContainerCardView
            if let existing = cardViews[stat.name] {
                card = existing
            } else {
                card = ContainerCardView()
                card.translatesAutoresizingMaskIntoConstraints = false
                cardViews[stat.name] = card
            }

            if card.superview !== col {
                col.addArrangedSubview(card)
                widthConstraints[stat.name]?.isActive = false
                let wc = card.widthAnchor.constraint(equalTo: col.widthAnchor)
                wc.isActive = true
                widthConstraints[stat.name] = wc
            }

            card.update(stat: stat, history: h)
        }
    }
}
