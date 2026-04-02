import AppKit
import SwiftUI

class EditorWindow: NSWindow {
    private let viewModel = EditorViewModel()
    private let canvas: AnnotationCanvas
    private let toolbarHosting: NSHostingView<ToolbarView>
    private static let toolbarHeight: CGFloat = 52

    init(screenshot: NSImage) {
        canvas = AnnotationCanvas()
        canvas.screenshot = screenshot

        // Placeholder — will be replaced after super.init
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
        titlebarAppearsTransparent = false
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
        // NSTextField uses NSText as its internal field editor — allow both through
        if responder is NSTextField || responder is NSText {
            return super.makeFirstResponder(responder)
        }
        return super.makeFirstResponder(canvas)
    }

    // MARK: - Export

    func copyToClipboard() {
        guard let image = canvas.flattenToImage(),
              let tiffData = image.tiffRepresentation else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(tiffData, forType: .tiff)

        // Brief visual flash to confirm copy
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
        let flash = NSTextField(labelWithString: "Copied!")
        flash.font = .systemFont(ofSize: 13, weight: .semibold)
        flash.textColor = .white
        flash.backgroundColor = NSColor.black.withAlphaComponent(0.75)
        flash.isBezeled = false
        flash.drawsBackground = true
        flash.sizeToFit()
        flash.frame = CGRect(
            x: (contentView!.bounds.width - flash.frame.width - 20) / 2,
            y: EditorWindow.toolbarHeight + 16,
            width: flash.frame.width + 20,
            height: flash.frame.height + 10
        )
        contentView?.addSubview(flash)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                flash.animator().alphaValue = 0
            } completionHandler: {
                flash.removeFromSuperview()
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

    private let presetColors: [(NSColor, Color)] = [
        (.systemRed, .red),
        (.systemBlue, .blue),
        (.systemGreen, .green),
        (.systemYellow, .yellow),
        (.systemOrange, .orange),
        (.white, .white)
    ]

    var body: some View {
        HStack(spacing: 6) {
            // — Інструменти —
            toolButton(icon: "rectangle",              tool: .rectangle)
            toolButton(icon: "arrow.up.right",         tool: .arrow)
            toolButton(icon: "textformat.abc",         tool: .text)
            toolButton(icon: "rectangle.fill",         tool: .fill,     help: "Fill (замазати кольором)")
            toolButton(icon: "square.grid.3x3.fill",   tool: .pixelate, help: "Blur (пікселізація)")

            Divider().frame(height: 22)

            // — Товщина лінії —
            ForEach(0..<3) { i in
                let sizes: [CGFloat] = [1.5, 3, 5.5]
                let size = sizes[i]
                Button { viewModel.selectedLineWidthIndex = i } label: {
                    RoundedRectangle(cornerRadius: size / 2)
                        .frame(width: 18, height: size)
                        .foregroundStyle(viewModel.selectedLineWidthIndex == i ? Color.accentColor : Color.primary.opacity(0.5))
                }
                .buttonStyle(.borderless)
                .help("Line weight \(i + 1)")
            }

            Divider().frame(height: 22)

            // — Кольори —
            ForEach(presetColors.indices, id: \.self) { i in
                let (_, swColor) = presetColors[i]
                Circle()
                    .fill(swColor)
                    .frame(width: 16, height: 16)
                    .overlay(Circle()
                        .stroke(viewModel.selectedColorIndex == i ? Color.primary : Color.clear, lineWidth: 2)
                        .padding(-2))
                    .shadow(radius: 1)
                    .onTapGesture { viewModel.selectedColorIndex = i }
            }

            Divider().frame(height: 22)

            Spacer()

            Button { sendAction("z") } label: { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(.borderless).help("Undo (⌘Z)")

            Button("Save") { sendAction("s") }
                .buttonStyle(.borderless).help("Save (⌘S)")

            Button("Copy") { sendAction("c") }
                .buttonStyle(.bordered).help("Copy (⌘C)")
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func toolButton(icon: String, tool: AnnotationTool, help: String? = nil) -> some View {
        Button { viewModel.selectedTool = tool } label: {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .background(viewModel.selectedTool == tool ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.borderless)
        .help(help ?? defaultHelp(tool))
    }

    private func defaultHelp(_ tool: AnnotationTool) -> String {
        switch tool {
        case .rectangle: return "Rectangle"
        case .arrow:     return "Arrow"
        case .text:      return "Text"
        case .fill:      return "Fill (замазати кольором)"
        case .pixelate:  return "Blur (пікселізація)"
        }
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
