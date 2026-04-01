import AppKit
import ScreenCaptureKit

class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()

    private var overlayWindow: SelectionOverlayWindow?
    private var editorWindow: EditorWindow?

    private init() {}

    // MARK: - Public

    func startCapture() {
        editorWindow?.close()
        editorWindow = nil

        let overlay = SelectionOverlayWindow()
        overlay.onCapture = { [weak self] cgRect in
            self?.overlayWindow = nil
            self?.captureRect(cgRect)
        }
        overlayWindow = overlay
        overlay.show()
        overlay.makeFirstResponder(overlay.contentView)
    }

    // MARK: - Capture

    private func captureRect(_ rect: CGRect) {
        Task {
            do {
                let cgImage = try await screenshotWithSCKit(rect: rect)
                await MainActor.run {
                    let size = NSSize(width: rect.width, height: rect.height)
                    let screenshot = NSImage(cgImage: cgImage, size: size)
                    self.openEditor(with: screenshot)
                }
            } catch {
                await MainActor.run { self.showPermissionAlert() }
            }
        }
    }

    private func screenshotWithSCKit(rect: CGRect) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        let mainScreenID = NSScreen.main?
            .deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        let display = content.displays.first { $0.displayID == mainScreenID } ?? content.displays[0]

        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0
        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width  = Int(rect.width  * scaleFactor)
        config.height = Int(rect.height * scaleFactor)
        config.scalesToFit = false
        config.captureResolution = .best

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    // MARK: - Helpers

    private func openEditor(with screenshot: NSImage) {
        let editor = EditorWindow(screenshot: screenshot)
        editorWindow = editor
        editor.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Enable Screeny in System Settings → Privacy & Security → Screen & System Audio Recording, then relaunch the app."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
            )
        }
    }
}
