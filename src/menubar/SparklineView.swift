import Cocoa

class SparklineView: NSView {
    var values: [Double] = [] { didSet { needsDisplay = true } }
    var lineColor: NSColor = .systemBlue
    var fixedMax: Double? = nil

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 36)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard values.count > 1 else { return }

        let w = bounds.width
        let h = bounds.height
        let vPad: CGFloat = 3
        let drawH = h - 2 * vPad
        let maxVal = fixedMax ?? max(values.max() ?? 1, 1)
        let stepX = w / CGFloat(values.count - 1)

        let path = NSBezierPath()
        for (i, v) in values.enumerated() {
            let x = CGFloat(i) * stepX
            let y = vPad + CGFloat(min(v, maxVal) / maxVal) * drawH
            if i == 0 { path.move(to: NSPoint(x: x, y: y)) }
            else       { path.line(to: NSPoint(x: x, y: y)) }
        }

        lineColor.setStroke()
        path.lineWidth = 1.5
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()

        let fill = path.copy() as! NSBezierPath
        fill.line(to: NSPoint(x: CGFloat(values.count - 1) * stepX, y: vPad))
        fill.line(to: NSPoint(x: 0, y: vPad))
        fill.close()
        lineColor.withAlphaComponent(0.12).setFill()
        fill.fill()
    }
}
