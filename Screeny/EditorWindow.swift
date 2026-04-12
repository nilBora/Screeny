import AppKit
import SwiftUI

class EditorWindow: NSWindow {
    private let viewModel = EditorViewModel()
    private let canvas: AnnotationCanvas
    private let toolbarHosting: NSHostingView<ToolbarView>
    static let toolbarHeight: CGFloat = 60

    init(screenshot: NSImage) {
        canvas = AnnotationCanvas()
        canvas.screenshot = screenshot

        toolbarHosting = NSHostingView(rootView: ToolbarView(viewModel: EditorViewModel()))

        let screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let imageSize = screenshot.size
        let maxW = screenFrame.width - 40
        let maxH = screenFrame.height - 80

        let scale = min(maxW / imageSize.width, maxH / imageSize.height, 1.0)
        let windowW = imageSize.width * scale
        let windowH = imageSize.height * scale + EditorWindow.toolbarHeight

        let x = (screenFrame.width - windowW) / 2 + screenFrame.minX
        let y = (screenFrame.height - windowH) / 2 + screenFrame.minY

        super.init(
            contentRect: CGRect(x: x, y: y, width: windowW, height: windowH),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        title = "Screeny"
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false

        setupViews(windowWidth: windowW, windowHeight: windowH, imageHeight: windowH - EditorWindow.toolbarHeight)
    }

    private func setupViews(windowWidth: CGFloat, windowHeight: CGFloat, imageHeight: CGFloat) {
        canvas.viewModel = viewModel

        let toolbarSwiftUI = ToolbarView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: toolbarSwiftUI)

        let contentView = NSView(frame: CGRect(x: 0, y: 0, width: windowWidth, height: windowHeight))

        canvas.frame = CGRect(x: 0, y: EditorWindow.toolbarHeight, width: windowWidth, height: imageHeight)
        canvas.autoresizingMask = [.width, .height]

        hosting.frame = CGRect(x: 0, y: 0, width: windowWidth, height: EditorWindow.toolbarHeight)
        hosting.autoresizingMask = [.width]

        contentView.addSubview(canvas)
        contentView.addSubview(hosting)
        self.contentView = contentView
    }

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        if responder is NSTextField || responder is NSText {
            return super.makeFirstResponder(responder)
        }
        return super.makeFirstResponder(canvas)
    }

    // MARK: - Key Equivalents

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.charactersIgnoringModifiers {
        case "c":
            if canvas.activeTextFieldHasSelection {
                return super.performKeyEquivalent(with: event)
            }
            canvas.commitTextFieldIfNeeded()
            copyToClipboard()
            return true
        case "s":
            canvas.commitTextFieldIfNeeded()
            saveToFile()
            return true
        case "z":
            canvas.commitTextFieldIfNeeded()
            canvas.undo()
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    // MARK: - Export

    func copyToClipboard() {
        guard let image = canvas.flattenToImage(),
              let tiffData = image.tiffRepresentation else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(tiffData, forType: .tiff)
        flashCopied()
    }

    func saveToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = "screenshot-\(Int(Date().timeIntervalSince1970))"
        panel.beginSheetModal(for: self) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            self.canvas.flattenToImage()?.save(to: url)
        }
    }

    private func flashCopied() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.72).cgColor
        container.layer?.cornerRadius = 10
        container.layer?.masksToBounds = true

        let label = NSTextField(labelWithString: "Copied to clipboard")
        label.font = .systemFont(ofSize: 12.5, weight: .semibold)
        label.textColor = .white
        label.isBezeled = false
        label.drawsBackground = false
        label.sizeToFit()

        let padH: CGFloat = 14
        let padV: CGFloat = 8
        let containerW = label.frame.width + padH * 2
        let containerH = label.frame.height + padV * 2

        label.frame = CGRect(x: padH, y: padV, width: label.frame.width, height: label.frame.height)

        container.frame = CGRect(
            x: (contentView!.bounds.width - containerW) / 2,
            y: EditorWindow.toolbarHeight + 16,
            width: containerW,
            height: containerH
        )
        container.alphaValue = 0

        container.addSubview(label)
        contentView?.addSubview(container)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            container.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                container.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                container.removeFromSuperview()
                self?.close()
            }
        }
    }
}

// MARK: - NSImage Save Helper

private extension NSImage {
    func save(to url: URL) {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return }

        let ext = url.pathExtension.lowercased()
        let fileType: NSBitmapImageRep.FileType = ext == "jpg" || ext == "jpeg" ? .jpeg : .png
        let props: [NSBitmapImageRep.PropertyKey: Any] = fileType == .jpeg ? [.compressionFactor: 0.9] : [:]

        if let data = bitmap.representation(using: fileType, properties: props) {
            try? data.write(to: url)
        }
    }
}

// MARK: - SwiftUI Toolbar

struct ToolbarView: View {
    @ObservedObject var viewModel: EditorViewModel

    @State private var hoveredTool: AnnotationTool? = nil
    @State private var hoveredLineWidth: Int? = nil
    @State private var hoveredColor: Int? = nil
    @State private var hoveredUndo = false
    @State private var hoveredSave = false
    @State private var hoveredCopy = false

    // Must match EditorViewModel.presetColors order
    private let swatchColors: [(Color, String)] = [
        (Color(nsColor: .systemRed),    "Red"),
        (Color(nsColor: .systemOrange), "Orange"),
        (Color(nsColor: .systemYellow), "Yellow"),
        (Color(nsColor: .systemGreen),  "Green"),
        (Color(nsColor: .systemBlue),   "Blue"),
        (.white,                        "White"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            toolsGroup
            separator
            lineWidthGroup
            separator
            colorsGroup
            separator
            Spacer()
            actionsGroup
        }
        .padding(.horizontal, 12)
        .frame(height: EditorWindow.toolbarHeight)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 0.5)
        }
    }

    // MARK: - Tools

    private var toolsGroup: some View {
        HStack(spacing: 1) {
            toolButton(icon: "rectangle",            tool: .rectangle, help: "Rectangle  R")
            toolButton(icon: "arrow.up.right",       tool: .arrow,     help: "Arrow  A")
            toolButton(icon: "character.cursor.ibeam", tool: .text,    help: "Text  T")
            toolButton(icon: "rectangle.fill",       tool: .fill,      help: "Fill / Redact")
            toolButton(icon: "aqi.medium",           tool: .pixelate,  help: "Blur / Pixelate")
        }
    }

    @ViewBuilder
    private func toolButton(icon: String, tool: AnnotationTool, help: String) -> some View {
        let isSelected = viewModel.selectedTool == tool
        let isHovered  = hoveredTool == tool

        Button {
            withAnimation(.easeOut(duration: 0.12)) {
                viewModel.selectedTool = tool
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(
                    isSelected
                        ? .white
                        : (isHovered ? Color.primary : Color.primary.opacity(0.55))
                )
                .frame(width: 34, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            isSelected
                                ? Color.accentColor
                                : (isHovered ? Color.primary.opacity(0.09) : Color.clear)
                        )
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
        .onHover { over in
            withAnimation(.easeOut(duration: 0.1)) {
                hoveredTool = over ? tool : nil
            }
        }
    }

    // MARK: - Line Width

    private var lineWidthGroup: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                let dotSizes: [CGFloat] = [5, 8, 12]
                let dot = dotSizes[i]
                let isSelected = viewModel.selectedLineWidthIndex == i
                let isHovered  = hoveredLineWidth == i

                Button {
                    withAnimation(.easeOut(duration: 0.12)) {
                        viewModel.selectedLineWidthIndex = i
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                isSelected
                                    ? Color.accentColor
                                    : Color.primary.opacity(isHovered ? 0.45 : 0.28)
                            )
                            .frame(width: dot, height: dot)
                    }
                    .frame(width: 30, height: 34)
                    .background {
                        if isHovered && !isSelected {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.primary.opacity(0.07))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help("Stroke weight \(i + 1)")
                .onHover { over in
                    withAnimation(.easeOut(duration: 0.1)) {
                        hoveredLineWidth = over ? i : nil
                    }
                }
            }
        }
    }

    // MARK: - Colors

    private var colorsGroup: some View {
        HStack(spacing: 3) {
            ForEach(swatchColors.indices, id: \.self) { i in
                let (color, name) = swatchColors[i]
                let isSelected = viewModel.selectedColorIndex == i
                let isHovered  = hoveredColor == i
                let isWhite    = name == "White"

                ZStack {
                    // Outer selection ring
                    if isSelected {
                        Circle()
                            .strokeBorder(
                                isWhite
                                    ? Color.primary.opacity(0.35)
                                    : color.opacity(0.45),
                                lineWidth: 2
                            )
                            .frame(width: 28, height: 28)
                    }

                    // Color fill
                    Circle()
                        .fill(color)
                        .frame(width: 18, height: 18)
                        .overlay {
                            if isWhite {
                                Circle()
                                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.75)
                            }
                        }

                    // Selection checkmark (only on dark-enough colors)
                    if isSelected && !isWhite {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 30, height: 34)
                .scaleEffect(isHovered && !isSelected ? 1.12 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.65), value: isHovered)
                .shadow(
                    color: isWhite ? .black.opacity(0.12) : color.opacity(isSelected ? 0.45 : 0.15),
                    radius: isSelected ? 6 : 2
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.12)) {
                        viewModel.selectedColorIndex = i
                    }
                }
                .onHover { over in
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.65)) {
                        hoveredColor = over ? i : nil
                    }
                }
                .help(name)
            }
        }
    }

    // MARK: - Actions

    private var actionsGroup: some View {
        HStack(spacing: 5) {
            // Undo
            Button {
                sendAction("z")
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(hoveredUndo ? Color.primary : Color.primary.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background {
                        if hoveredUndo {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.primary.opacity(0.09))
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Undo  ⌘Z")
            .onHover { over in
                withAnimation(.easeOut(duration: 0.1)) { hoveredUndo = over }
            }

            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 0.5, height: 20)
                .padding(.horizontal, 4)

            // Save
            Button {
                sendAction("s")
            } label: {
                Text("Save")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(hoveredSave ? Color.primary : Color.primary.opacity(0.75))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5.5)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                hoveredSave
                                    ? Color.primary.opacity(0.13)
                                    : Color.primary.opacity(0.08)
                            )
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Save to file  ⌘S")
            .onHover { over in
                withAnimation(.easeOut(duration: 0.1)) { hoveredSave = over }
            }

            // Copy (primary action)
            Button {
                sendAction("c")
            } label: {
                Text("Copy")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 5.5)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                hoveredCopy
                                    ? Color.accentColor.opacity(0.85)
                                    : Color.accentColor
                            )
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Copy to clipboard  ⌘C")
            .onHover { over in
                withAnimation(.easeOut(duration: 0.1)) { hoveredCopy = over }
            }
        }
    }

    // MARK: - Helpers

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 0.5, height: 22)
            .padding(.horizontal, 10)
    }

    private func sendAction(_ key: String) {
        guard let window = NSApp.windows.first(where: { $0 is EditorWindow }) as? EditorWindow else { return }
        switch key {
        case "z": window.contentView?.subviews.compactMap { $0 as? AnnotationCanvas }.first?.undo()
        case "c": window.copyToClipboard()
        case "s": window.saveToFile()
        default: break
        }
    }
}
