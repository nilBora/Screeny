import AppKit

class AnnotationCanvas: NSView, NSTextFieldDelegate {
    var screenshot: NSImage?
    var viewModel: EditorViewModel?

    private(set) var annotations: [Annotation] = []
    private var currentAnnotation: Annotation?
    private var dragStart: CGPoint = .zero

    private var activeTextField: NSTextField?
    private var activeTextPosition: CGPoint = .zero

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Public

    func undo() {
        guard !annotations.isEmpty else { return }
        annotations.removeLast()
        needsDisplay = true
    }

    func flattenToImage() -> NSImage? {
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        cacheDisplay(in: bounds, to: rep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        screenshot?.draw(in: bounds)
        for annotation in annotations { draw(annotation: annotation) }
        if let current = currentAnnotation { draw(annotation: current) }
    }

    private func draw(annotation: Annotation) {
        switch annotation {
        case let .rectangle(rect, color, lineWidth):
            let path = NSBezierPath(rect: rect)
            path.lineWidth = lineWidth
            color.setStroke()
            path.stroke()

        case let .arrow(start, end, color, lineWidth):
            drawArrow(from: start, to: end, color: color, lineWidth: lineWidth)

        case let .text(string, position, color, fontSize):
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: color,
                .strokeColor: NSColor.black.withAlphaComponent(0.4),
                .strokeWidth: -1.5
            ]
            string.draw(at: position, withAttributes: attrs)

        case let .fill(rect, color):
            color.setFill()
            NSBezierPath(rect: rect).fill()

        case let .pixelate(rect):
            drawPixelated(at: rect)
        }
    }

    // MARK: - Pixelate

    private func drawPixelated(at rect: CGRect) {
        guard let screenshot,
              let cgImage = screenshot.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return }

        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        let scaleX = imgW / screenshot.size.width
        let scaleY = imgH / screenshot.size.height

        // NSView bottom-left → CGImage top-left
        let cropRect = CGRect(
            x: rect.minX * scaleX,
            y: (screenshot.size.height - rect.maxY) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )

        guard let cropped = cgImage.cropping(to: cropRect) else { return }

        let ci = CIImage(cgImage: cropped)
        let scale = max(10.0, min(rect.width, rect.height) / 6)

        guard let filter = CIFilter(name: "CIPixellate",
                                    parameters: [kCIInputImageKey: ci,
                                                 kCIInputScaleKey: scale]),
              let output = filter.outputImage else { return }

        let ctx = CIContext()
        guard let result = ctx.createCGImage(output, from: output.extent) else { return }

        NSImage(cgImage: result, size: rect.size).draw(in: rect)
    }

    // MARK: - Arrow

    private func drawArrow(from start: CGPoint, to end: CGPoint, color: NSColor, lineWidth: CGFloat) {
        color.setStroke()

        let shaft = NSBezierPath()
        shaft.move(to: start)
        shaft.line(to: end)
        shaft.lineWidth = lineWidth
        shaft.lineCapStyle = .round
        shaft.stroke()

        let arrowLength: CGFloat = max(14, lineWidth * 4)
        let angle = atan2(end.y - start.y, end.x - start.x)
        let spread: CGFloat = .pi / 5.5

        let head = NSBezierPath()
        head.move(to: end)
        head.line(to: CGPoint(x: end.x - arrowLength * cos(angle - spread),
                              y: end.y - arrowLength * sin(angle - spread)))
        head.move(to: end)
        head.line(to: CGPoint(x: end.x - arrowLength * cos(angle + spread),
                              y: end.y - arrowLength * sin(angle + spread)))
        head.lineWidth = lineWidth
        head.lineCapStyle = .round
        head.stroke()
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        dragStart = point

        if viewModel?.selectedTool == .text {
            commitActiveTextField()
            showTextField(at: point)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let tool = viewModel?.selectedTool
        guard tool != .text else { return }

        let point = convert(event.locationInWindow, from: nil)
        let color = viewModel?.selectedColor ?? .systemRed
        let lineWidth = viewModel?.currentLineWidth ?? 3.0

        let rect = CGRect(
            x: min(dragStart.x, point.x), y: min(dragStart.y, point.y),
            width: abs(point.x - dragStart.x), height: abs(point.y - dragStart.y)
        )

        switch tool {
        case .rectangle:
            currentAnnotation = .rectangle(rect: rect, color: color, lineWidth: lineWidth)
        case .arrow:
            currentAnnotation = .arrow(start: dragStart, end: point, color: color, lineWidth: lineWidth)
        case .fill:
            currentAnnotation = .fill(rect: rect, color: color)
        case .pixelate:
            currentAnnotation = .pixelate(rect: rect)
        default:
            break
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let current = currentAnnotation {
            annotations.append(current)
            currentAnnotation = nil
            needsDisplay = true
        }
    }

    // MARK: - Text Input

    private func showTextField(at point: CGPoint) {
        activeTextPosition = point

        let field = NSTextField(frame: CGRect(x: point.x, y: point.y - 22, width: 220, height: 28))
        field.isEditable = true
        field.isBordered = false
        field.drawsBackground = false
        field.textColor = viewModel?.selectedColor ?? .systemRed
        field.font = .systemFont(ofSize: 16, weight: .semibold)
        field.placeholderString = "Type here, press Enter"
        field.delegate = self
        field.focusRingType = .none
        addSubview(field)
        window?.makeFirstResponder(field)
        activeTextField = field
    }

    private func commitActiveTextField() {
        guard let field = activeTextField else { return }
        if !field.stringValue.isEmpty {
            annotations.append(.text(
                string: field.stringValue,
                position: CGPoint(x: activeTextPosition.x, y: activeTextPosition.y - 18),
                color: viewModel?.selectedColor ?? .systemRed,
                fontSize: 16
            ))
        }
        field.removeFromSuperview()
        activeTextField = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        commitActiveTextField()
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "z": undo()
            case "c": (window as? EditorWindow)?.copyToClipboard()
            case "s": (window as? EditorWindow)?.saveToFile()
            default: super.keyDown(with: event)
            }
        } else if event.keyCode == 53 { // Esc
            window?.close()
        } else {
            super.keyDown(with: event)
        }
    }
}
