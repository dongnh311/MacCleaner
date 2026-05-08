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

    // White-tile background à la MS Office app icons — subtle vertical
    // gradient from pure white at top to faint cool-grey at bottom so
    // the squircle has a hint of depth without a hard border.
    let bgColors = [
        CGColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0),
        CGColor(red: 0.93, green: 0.95, blue: 0.98, alpha: 1.0)
    ]
    let bgGradient = CGGradient(colorsSpace: cs, colors: bgColors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

    // Center sparkle glyph rendered as a four-pointed star + small accents.
    // Sized to match the visual weight of MS Office / Apple stock app icons
    // (their glyphs occupy ~70% of the canvas — anything smaller and the
    // icon looks visibly less "filled" in the Dock).
    let cx = s * 0.5
    let cy = s * 0.5
    let bigR = s * 0.22   // outer radius of main star — main glyph sized
    let bigInner = s * 0.055 // smaller than Office apps so sparkle reads as a logo accent

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

    // Main star: paint a clipped path filled with the brand gradient so
    // the star itself reads as the brand colour against the white tile.
    let starPath = CGMutablePath()
    do {
        let points = 4
        for i in 0..<(points * 2) {
            let r = (i % 2 == 0) ? bigR : bigInner
            let theta = (CGFloat(i) / CGFloat(points * 2)) * .pi * 2 - .pi / 2
            let x = cx + cos(theta) * r
            let y = cy + sin(theta) * r
            if i == 0 { starPath.move(to: CGPoint(x: x, y: y)) }
            else      { starPath.addLine(to: CGPoint(x: x, y: y)) }
        }
        starPath.closeSubpath()
    }
    let starGradient = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 0.42, green: 0.32, blue: 0.96, alpha: 1.0),  // violet
            CGColor(red: 0.10, green: 0.62, blue: 0.96, alpha: 1.0)   // cyan-blue
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.saveGState()
    ctx.addPath(starPath)
    ctx.clip()
    ctx.drawLinearGradient(starGradient, start: CGPoint(x: cx - bigR, y: cy + bigR), end: CGPoint(x: cx + bigR, y: cy - bigR), options: [])
    ctx.restoreGState()

    // Accent stars in the same brand colour but at lower opacity so the
    // central glyph stays the focal point.
    drawStar(centerX: cx + s * 0.20, centerY: cy + s * 0.19, outerR: s * 0.07, innerR: s * 0.017,
             color: CGColor(red: 0.30, green: 0.45, blue: 0.96, alpha: 0.85))
    drawStar(centerX: cx - s * 0.22, centerY: cy - s * 0.17, outerR: s * 0.055, innerR: s * 0.014,
             color: CGColor(red: 0.30, green: 0.45, blue: 0.96, alpha: 0.65))

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
