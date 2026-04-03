#!/usr/bin/swift
import Foundation
import CoreGraphics
import ImageIO

// MARK: - Draw

func createIcon(size: Int) -> CGImage? {
    let s = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    guard let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // — Background rounded rect —
    let radius = s * 0.225
    let bgPath = CGMutablePath()
    bgPath.addRoundedRect(in: CGRect(x: 0, y: 0, width: s, height: s),
                          cornerWidth: radius, cornerHeight: radius)

    let topColor    = CGColor(red: 0.22, green: 0.52, blue: 1.00, alpha: 1)
    let bottomColor = CGColor(red: 0.06, green: 0.28, blue: 0.80, alpha: 1)
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [topColor, bottomColor] as CFArray,
        locations: [0, 1]
    )!

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    ctx.drawLinearGradient(gradient,
        start: CGPoint(x: s / 2, y: s),
        end:   CGPoint(x: s / 2, y: 0),
        options: [])
    ctx.restoreGState()

    // — Selection rectangle (inner semi-transparent box) —
    let margin  = s * 0.175
    let selRect = CGRect(x: margin, y: margin,
                         width: s - margin * 2, height: s - margin * 2)

    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.1)
    ctx.fill(selRect)

    // — Corner L-brackets —
    let bLen = s * 0.165   // bracket arm length
    let bW   = s * 0.052   // stroke width

    ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.95)
    ctx.setLineWidth(bW)
    ctx.setLineCap(.square)

    let corners: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (margin, margin, 1, 1),
        (s - margin, margin, -1, 1),
        (margin, s - margin, 1, -1),
        (s - margin, s - margin, -1, -1)
    ]
    for (x, y, hd, vd) in corners {
        ctx.move(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x + bLen * hd, y: y))
        ctx.move(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x, y: y + bLen * vd))
        ctx.strokePath()
    }

    // — Center crosshair —
    let cHalf = s * 0.065
    let cx    = s * 0.5
    let cy    = s * 0.5

    ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.80)
    ctx.setLineWidth(bW * 0.60)
    ctx.setLineCap(.round)

    // horizontal
    ctx.move(to: CGPoint(x: cx - cHalf, y: cy))
    ctx.addLine(to: CGPoint(x: cx + cHalf, y: cy))
    // vertical
    ctx.move(to: CGPoint(x: cx, y: cy - cHalf))
    ctx.addLine(to: CGPoint(x: cx, y: cy + cHalf))
    ctx.strokePath()

    // — Small dot at center —
    let dotR = bW * 0.5
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.90)
    ctx.fillEllipse(in: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2))

    return ctx.makeImage()
}

// MARK: - Save

func savePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil) else {
        print("✗ Failed: \(path)"); return
    }
    CGImageDestinationAddImage(dest, image, nil)
    if CGImageDestinationFinalize(dest) {
        print("✓ \((path as NSString).lastPathComponent)")
    } else {
        print("✗ Finalize failed: \(path)")
    }
}

// MARK: - Generate all sizes

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath

let sizes = [16, 32, 64, 128, 256, 512, 1024]
for px in sizes {
    if let img = createIcon(size: px) {
        savePNG(img, to: "\(outDir)/icon_\(px).png")
    } else {
        print("✗ Could not create icon at \(px)px")
    }
}
print("Done → \(outDir)")
