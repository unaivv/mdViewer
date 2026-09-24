#!/usr/bin/env swift
// Generates the macOS app icon PNGs into the AppIcon asset catalog.
// Usage: swift scripts/generate-icon.swift
import AppKit

let outputDir = URL(fileURLWithPath: "MdViewer/Resources/Assets.xcassets/AppIcon.appiconset")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// Draws the icon on a 1024×1024 canvas (origin bottom-left).
func drawIcon(in ctx: CGContext) {
    // Background squircle following the macOS icon grid (824pt body, 100pt margin).
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(bodyPath)
    ctx.setFillColor(color(0x3A43C9))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(0x6A7BFF), color(0x2B2F8F)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    // Document page with a folded top-right corner.
    let page = CGRect(x: 262, y: 196, width: 500, height: 632)
    let fold: CGFloat = 118
    let pagePath = CGMutablePath()
    pagePath.move(to: CGPoint(x: page.minX + 36, y: page.minY))
    pagePath.addLine(to: CGPoint(x: page.maxX - 36, y: page.minY))
    pagePath.addQuadCurve(to: CGPoint(x: page.maxX, y: page.minY + 36), control: CGPoint(x: page.maxX, y: page.minY))
    pagePath.addLine(to: CGPoint(x: page.maxX, y: page.maxY - fold))
    pagePath.addLine(to: CGPoint(x: page.maxX - fold, y: page.maxY))
    pagePath.addLine(to: CGPoint(x: page.minX + 36, y: page.maxY))
    pagePath.addQuadCurve(to: CGPoint(x: page.minX, y: page.maxY - 36), control: CGPoint(x: page.minX, y: page.maxY))
    pagePath.addLine(to: CGPoint(x: page.minX, y: page.minY + 36))
    pagePath.addQuadCurve(to: CGPoint(x: page.minX + 36, y: page.minY), control: CGPoint(x: page.minX, y: page.minY))
    pagePath.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x10124A, 0.45))
    ctx.addPath(pagePath)
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()

    let foldPath = CGMutablePath()
    foldPath.move(to: CGPoint(x: page.maxX - fold, y: page.maxY))
    foldPath.addLine(to: CGPoint(x: page.maxX - fold, y: page.maxY - fold + 24))
    foldPath.addQuadCurve(
        to: CGPoint(x: page.maxX - fold + 24, y: page.maxY - fold),
        control: CGPoint(x: page.maxX - fold, y: page.maxY - fold)
    )
    foldPath.addLine(to: CGPoint(x: page.maxX, y: page.maxY - fold))
    foldPath.closeSubpath()
    ctx.addPath(foldPath)
    ctx.setFillColor(color(0xCDD3F4))
    ctx.fillPath()

    // Heading bar.
    let ink = color(0x2B2F8F)
    ctx.setFillColor(ink)
    ctx.addPath(CGPath(roundedRect: CGRect(x: 318, y: 712, width: 230, height: 34), cornerWidth: 17, cornerHeight: 17, transform: nil))
    ctx.fillPath()

    // Markdown mark: outlined badge with "M" and a down arrow.
    let badge = CGRect(x: 318, y: 448, width: 388, height: 222)
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(24)
    ctx.addPath(CGPath(roundedRect: badge, cornerWidth: 40, cornerHeight: 40, transform: nil))
    ctx.strokePath()

    ctx.setLineWidth(34)
    ctx.setLineJoin(.miter)
    ctx.setLineCap(.butt)
    ctx.move(to: CGPoint(x: 380, y: 498))
    ctx.addLine(to: CGPoint(x: 380, y: 618))
    ctx.addLine(to: CGPoint(x: 438, y: 556))
    ctx.addLine(to: CGPoint(x: 496, y: 618))
    ctx.addLine(to: CGPoint(x: 496, y: 498))
    ctx.strokePath()

    ctx.move(to: CGPoint(x: 612, y: 622))
    ctx.addLine(to: CGPoint(x: 612, y: 548))
    ctx.strokePath()
    ctx.setFillColor(ink)
    ctx.move(to: CGPoint(x: 560, y: 556))
    ctx.addLine(to: CGPoint(x: 664, y: 556))
    ctx.addLine(to: CGPoint(x: 612, y: 494))
    ctx.closePath()
    ctx.fillPath()

    // Body text lines.
    ctx.setFillColor(color(0xB9C0E8))
    for (y, width) in [(372.0, 388.0), (320.0, 340.0), (268.0, 260.0)] {
        ctx.addPath(CGPath(roundedRect: CGRect(x: 318, y: y, width: width, height: 22), cornerWidth: 11, cornerHeight: 11, transform: nil))
        ctx.fillPath()
    }
}

func renderPNG(pixels: Int, to url: URL) throws {
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(in: ctx)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try renderPNG(pixels: size * scale, to: outputDir.appendingPathComponent(name))
        images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(size)x\(size)", "filename": name])
    }
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: outputDir.appendingPathComponent("Contents.json"))
print("Generated \(images.count) icon images in \(outputDir.path)")
