# Screeny — Claude Code Context

## Project
Minimal macOS menu bar screenshot app with annotation tools. Built with SwiftUI + AppKit.

## Structure
```
Screeny.xcodeproj/        — Xcode project (deployment target: macOS 14.0)
Screeny/
  ScreenyApp.swift         — @main entry point
  AppDelegate.swift        — Menu bar icon, global hotkey (Ctrl+Shift+4) via Carbon
  ScreenCaptureManager.swift — Capture flow using ScreenCaptureKit (SCScreenshotManager)
  SelectionOverlayWindow.swift — Full-screen transparent NSWindow for area selection
  EditorWindow.swift       — NSWindow with AnnotationCanvas + SwiftUI ToolbarView
  AnnotationCanvas.swift   — NSView handling drawing, mouse events, text input
  EditorViewModel.swift    — ObservableObject shared between canvas and toolbar
  Annotation.swift         — Annotation enum (rectangle, arrow, text, fill, pixelate)
  Assets.xcassets/         — AppIcon (all macOS sizes 16–1024px)
  Info.plist               — LSUIElement=true, NSScreenCaptureUsageDescription
  Screeny.entitlements     — app-sandbox=false
ScreenyTests/
  EditorViewModelTests.swift  — Unit tests for EditorViewModel
  AnnotationCanvasTests.swift — Unit tests for AnnotationCanvas
.github/workflows/
  release.yml              — CI: builds app, creates DMG, publishes GitHub release on tag push
Makefile                   — make build / make dmg / make clean
```

## Key Architecture Decisions
- **AppKit + SwiftUI hybrid**: NSWindow/NSView for the editor canvas (mouse events, drawing), NSHostingView<ToolbarView> for the SwiftUI toolbar
- **No App Sandbox**: Simplifies screen recording permission; set in Screeny.entitlements
- **ScreenCaptureKit**: Uses SCScreenshotManager (macOS 14+) for capture — sees all windows. CGWindowListCreateImage was abandoned because it only captures wallpaper on macOS 14+ without proper permission recognition
- **Carbon hotkeys**: RegisterEventHotKey for global Ctrl+Shift+4 (avoids conflicts with system Cmd+Shift+4)
- **Coordinate systems**: SelectionOverlayWindow converts NSView bottom-left coords to CG top-left coords before passing to SCScreenshotManager.sourceRect
- **TCC Permission issue**: Screen recording permission is tied to binary code signature. App must be code-signed (Xcode → Signing & Capabilities → Team) and run from /Applications for permission to persist across builds. Build phase auto-copies to /Applications after each build.
- **performKeyEquivalent override**: EditorWindow intercepts Cmd+C/S/Z at window level to handle shortcuts regardless of first responder. Cmd+C copies screenshot unless text is selected in the active NSTextField (in which case native copy is used).

## Tools
| Tool | Annotation Type | Notes |
|------|----------------|-------|
| Rectangle | `.rectangle(rect, color, lineWidth)` | Stroke only |
| Arrow | `.arrow(start, end, color, lineWidth)` | Line + arrowhead via NSBezierPath |
| Text | `.text(string, position, color, fontSize)` | NSTextField overlay → commits on Enter/blur |
| Fill | `.fill(rect, color)` | Solid color fill for censoring |
| Pixelate | `.pixelate(rect)` | CIPixellate filter on screenshot crop |

## Export
- **Cmd+C**: `AnnotationCanvas.flattenToImage()` → NSPasteboard (TIFF). If text field is active with a selection, copies text instead.
- **Cmd+S**: NSSavePanel → PNG or JPEG

## Release
- Tag `v*` on main triggers `.github/workflows/release.yml` — builds with `xcodebuild`, creates DMG via `hdiutil`, publishes GitHub release
- Local: `make dmg VERSION=1.0.1` → `Screeny-1.0.1.dmg`

## Known Issues / Gotchas
- Text field focus: EditorWindow.makeFirstResponder must pass through both NSTextField AND NSText (field editor), otherwise the text tool is unresponsive
- SCScreenshotManager requires macOS 14.0+
- Permission won't persist without proper code signing — run `tccutil reset ScreenCapture com.screeny.app` after signing setup
- Build phase "Copy to Applications" copies .app to /Applications after every build for stable permission binding
- GitHub Actions build uses `CODE_SIGNING_REQUIRED=NO` — released DMG is unsigned, users must right-click → Open to bypass Gatekeeper
