<p align="center">
  <img src="Screeny/Assets.xcassets/AppIcon.appiconset/icon_128.png" width="96" alt="Screeny icon">
</p>

# Screeny

A minimal macOS menu bar app for instant screenshot capture and annotation.

## Features

- **Area capture** — select any region of the screen with a crosshair overlay
- **Annotation tools**:
  - Rectangle (stroke)
  - Arrow
  - Text
  - Fill — solid color block for censoring sensitive content
  - Blur — pixelation effect for censoring
- **Line thickness** — three preset sizes
- **Color picker** — 6 preset colors
- **Export** — copy to clipboard (`Cmd+C`) or save as PNG/JPEG (`Cmd+S`)
- **Undo** — `Cmd+Z`
- **Menu bar app** — no Dock icon, lives quietly in the menu bar

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15 or later (to build)
- Screen Recording permission

## Getting Started

### 1. Build

Open `Screeny.xcodeproj` in Xcode.

Before the first build, set up code signing to ensure screen recording permission persists between builds:

> **Xcode → Target "Screeny" → Signing & Capabilities → Team** → select your Apple ID

Then build with `Cmd+B`. The build phase automatically copies `Screeny.app` to `/Applications`.

### 2. Grant Permission

Launch `/Applications/Screeny.app` and go to:

> **System Settings → Privacy & Security → Screen & System Audio Recording** → enable Screeny

If you need to reset a stale permission entry:
```bash
tccutil reset ScreenCapture com.screeny.app
```

### 3. Use

| Action | Shortcut |
|--------|----------|
| Capture area | `Ctrl+Shift+4` |
| Copy to clipboard | `Cmd+C` |
| Save to file | `Cmd+S` |
| Undo annotation | `Cmd+Z` |
| Close editor | `Esc` |

## Project Structure

```
Screeny/
├── ScreenyApp.swift              # App entry point
├── AppDelegate.swift             # Menu bar + global hotkey (Carbon)
├── ScreenCaptureManager.swift    # Screen capture via ScreenCaptureKit
├── SelectionOverlayWindow.swift  # Fullscreen selection overlay
├── EditorWindow.swift            # Editor window + SwiftUI toolbar
├── AnnotationCanvas.swift        # Drawing canvas (AppKit NSView)
├── EditorViewModel.swift         # Shared state (tool, color, line width)
├── Annotation.swift              # Annotation model
├── Info.plist
└── Screeny.entitlements
```

## Architecture

Screeny uses an **AppKit + SwiftUI hybrid** approach:

- `NSWindow` / `NSView` for the editor canvas — direct control over mouse events and Core Graphics drawing
- `NSHostingView<ToolbarView>` embeds a SwiftUI view for the toolbar
- `EditorViewModel` (ObservableObject) bridges the two layers
- `ScreenCaptureKit` (`SCScreenshotManager`) for capture — correctly captures all on-screen windows including those above the overlay
- `Carbon RegisterEventHotKey` for a global hotkey that doesn't conflict with system shortcuts

## License

MIT
