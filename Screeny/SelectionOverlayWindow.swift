import AppKit

// MARK: - Window

class SelectionOverlayWindow: NSWindow {
    private let overlayView = SelectionOverlayView()
    var onCapture: ((CGRect) -> Void)?

    init() {
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        backgroundColor = .clear
        isOpaque = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false

        contentView = overlayView
        overlayView.onSelectionComplete = { [weak self] viewRect in
            self?.finishCapture(viewRect: viewRect)
        }
    }

    func show() {
        makeKeyAndOrderFront(nil)
        overlayView.reset()
        NSCursor.crosshair.set()
    }

    private func finishCapture(viewRect: CGRect) {
        orderOut(nil)
        NSCursor.arrow.set()

        // Wait for the overlay to disappear from the screen buffer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            let cgRect = self.convertToCGCoordinates(viewRect: viewRect)
            self.onCapture?(cgRect)
        }
    }

    // NSView (AppKit) has bottom-left origin; CGWindowListCreateImage uses top-left
    private func convertToCGCoordinates(viewRect: CGRect) -> CGRect {
        let screenHeight = NSScreen.main?.frame.height ?? 900
        return CGRect(
            x: viewRect.minX,
            y: screenHeight - viewRect.maxY,
            width: viewRect.width,
            height: viewRect.height
        )
    }
}

// MARK: - View

class SelectionOverlayView: NSView {
    var onSelectionComplete: ((CGRect) -> Void)?

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var selectionRect: CGRect? {
        guard let s = startPoint, let c = currentPoint else { return nil }
        return CGRect(
            x: min(s.x, c.x), y: min(s.y, c.y),
            width: abs(c.x - s.x), height: abs(c.y - s.y)
        )
    }

    func reset() {
        startPoint = nil
        currentPoint = nil
        needsDisplay = true
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        guard let rect = selectionRect, rect.width > 5, rect.height > 5 else {
            reset()
            window?.orderOut(nil)
            return
        }
        onSelectionComplete?(rect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            reset()
            window?.orderOut(nil)
            NSCursor.arrow.set()
        }
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        let overlayColor = NSColor.black.withAlphaComponent(0.45)

        if let sel = selectionRect {
            // Draw 4 dark rectangles around the selection, leaving it clear
            overlayColor.setFill()
            NSRect(x: 0, y: sel.maxY, width: bounds.width, height: bounds.maxY - sel.maxY).fill()
            NSRect(x: 0, y: 0, width: bounds.width, height: sel.minY).fill()
            NSRect(x: 0, y: sel.minY, width: sel.minX, height: sel.height).fill()
            NSRect(x: sel.maxX, y: sel.minY, width: bounds.maxX - sel.maxX, height: sel.height).fill()

            // Selection border
            NSColor.white.withAlphaComponent(0.9).setStroke()
            let border = NSBezierPath(rect: sel)
            border.lineWidth = 1.5
            border.stroke()

            // Size label
            drawSizeLabel(for: sel)
        } else {
            overlayColor.setFill()
            bounds.fill()
        }
    }

    private func drawSizeLabel(for rect: CGRect) {
        let label = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = label.size(withAttributes: attrs)
        let padding: CGFloat = 4
        let labelRect = CGRect(
            x: rect.midX - size.width / 2 - padding,
            y: rect.minY - size.height - 8 - padding * 2,
            width: size.width + padding * 2,
            height: size.height + padding * 2
        )
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4).fill()
        label.draw(at: CGPoint(x: labelRect.minX + padding, y: labelRect.minY + padding), withAttributes: attrs)
    }
}
