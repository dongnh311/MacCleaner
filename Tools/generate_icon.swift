#!/usr/bin/env swift
import AppKit
import Foundation

// One-shot generator: writes PNG files for the AppIcon asset catalog.
// Run from repo root:  swift Tools/generate_icon.swift

let outDir = URL(fileURLWithPath: "Resources/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func renderIcon(size pixelSize: Int) -> Data {
    let s = CGFloat(pixelSize)
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // Rounded-square clip
    let cornerRadius = s * 0.225
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let clipPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(clipPath); ctx.clip()

    // Background gradient (purple → cyan, top-left → bottom-right)
    let colors = [
        CGColor(red: 0.42, green: 0.32, blue: 0.96, alpha: 1.0),  // violet
        CGColor(red: 0.10, green: 0.62, blue: 0.96, alpha: 1.0)   // cyan-blue
    ]
    let gradient = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

    // Subtle inner highlight (top edge)
    let highlight = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.18),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(highlight, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: s * 0.5), options: [])

    // Center sparkle glyph rendered as a four-pointed star + small accents.
    // Sized to match the visual weight of MS Office / Apple stock app icons
    // (their glyphs occupy ~70% of the canvas — anything smaller and the
    // icon looks visibly less "filled" in the Dock).
    let cx = s * 0.5
    let cy = s * 0.5
    let bigR = s * 0.36   // outer radius of main star — matches the
    let bigInner = s * 0.085 // visual weight of MS Office / Apple stock app icons

    func drawStar(centerX: CGFloat, centerY: CGFloat, outerR: CGFloat, innerR: CGFloat, color: CGColor) {
        let path = CGMutablePath()
        let points = 4
        for i in 0..<(points * 2) {
            let r = (i % 2 == 0) ? outerR : innerR
            let theta = (CGFloat(i) / CGFloat(points * 2)) * .pi * 2 - .pi / 2
            let x = centerX + cos(theta) * r
            let y = centerY + sin(theta) * r
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setFillColor(color)
        ctx.fillPath()
    }

    // Drop shadow under main star
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.04, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.25))
    drawStar(centerX: cx, centerY: cy, outerR: bigR, innerR: bigInner, color: CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.restoreGState()

    // Two small accent stars push toward the corners so the central
    // glyph feels grounded — proportions scaled up with the bigger main
    // star above.
    drawStar(centerX: cx + s * 0.27, centerY: cy + s * 0.24, outerR: s * 0.11, innerR: s * 0.028,
             color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    drawStar(centerX: cx - s * 0.29, centerY: cy - s * 0.22, outerR: s * 0.085, innerR: s * 0.022,
             color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.85))

    // Convert to PNG
    guard let cg = ctx.makeImage() else { fatalError("failed to make image at \(pixelSize)") }
    let rep = NSBitmapImageRep(cgImage: cg)
    return rep.representation(using: .png, properties: [:])!
}

let entries: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for entry in entries {
    let data = renderIcon(size: entry.pixels)
    let url = outDir.appendingPathComponent(entry.name)
    try data.write(to: url)
    print("wrote \(entry.name) (\(entry.pixels)x\(entry.pixels))")
}

// Asset catalog Contents.json files
let appIconContents = """
{
  "images" : [
    {"size":"16x16","idiom":"mac","filename":"icon_16x16.png","scale":"1x"},
    {"size":"16x16","idiom":"mac","filename":"icon_16x16@2x.png","scale":"2x"},
    {"size":"32x32","idiom":"mac","filename":"icon_32x32.png","scale":"1x"},
    {"size":"32x32","idiom":"mac","filename":"icon_32x32@2x.png","scale":"2x"},
    {"size":"128x128","idiom":"mac","filename":"icon_128x128.png","scale":"1x"},
    {"size":"128x128","idiom":"mac","filename":"icon_128x128@2x.png","scale":"2x"},
    {"size":"256x256","idiom":"mac","filename":"icon_256x256.png","scale":"1x"},
    {"size":"256x256","idiom":"mac","filename":"icon_256x256@2x.png","scale":"2x"},
    {"size":"512x512","idiom":"mac","filename":"icon_512x512.png","scale":"1x"},
    {"size":"512x512","idiom":"mac","filename":"icon_512x512@2x.png","scale":"2x"}
  ],
  "info" : { "version":1, "author":"xcode" }
}
"""
try appIconContents.write(to: outDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("wrote AppIcon Contents.json")

let catalogContents = """
{
  "info" : { "version":1, "author":"xcode" }
}
"""
let catalog = URL(fileURLWithPath: "Resources/Assets.xcassets")
try catalogContents.write(to: catalog.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("wrote Assets.xcassets Contents.json")
