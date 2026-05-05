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

## Install

### Homebrew (recommended)

```bash
brew tap nilbora/apps
brew install --cask screeny
```

Grant Screen Recording permission on first launch:

> **System Settings → Privacy & Security → Screen & System Audio Recording** → enable Screeny

### Manual

Download the latest DMG from [Releases](https://github.com/nilBora/Screeny/releases), drag `Screeny.app` to `/Applications`, and grant Screen Recording permission as above.

---

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15 or later (to build from source)
- Screen Recording permission

## Build from Source

### 1. Build

Open `Screeny.xcodeproj` in Xcode.

Before the first build, set up code signing to ensure screen recording permission persists between builds:

> **Xcode → Target "Screeny" → Signing & Capabilities → Team** → select your Apple ID

Then build with `Cmd+B`. The build phase automatically copies `Screeny.app` to `/Applications`.

Grant Screen Recording permission as described in the Install section above. To reset a stale entry:
```bash
tccutil reset ScreenCapture com.screeny.app
```

### 2. Use

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
