import AppKit

/// Scanline-style flood fill on an `NSBitmapImageRep`. Tolerance is fixed
/// (anti-aliased edges of a stroke sit a few RGB steps off the target so
/// a hard `==` match leaves a fringe).
enum FloodFill {

    static func fill(bitmap rep: NSBitmapImageRep, at point: CGPoint, with newColor: NSColor) {
        let w = rep.pixelsWide
        let h = rep.pixelsHigh
        // NSBitmapImageRep pixel coords are top-left origin; convert from
        // canvas (bottom-up) Y.
        let sx = Int(point.x.rounded())
        let sy = h - 1 - Int(point.y.rounded())
        guard sx >= 0, sy >= 0, sx < w, sy < h, let data = rep.bitmapData else { return }
        let bytesPerRow = rep.bytesPerRow
        let bpp = rep.bitsPerPixel / 8 // expected 4 (RGBA)
        guard bpp >= 3 else { return }

        let target = pixel(data: data, x: sx, y: sy, row: bytesPerRow, bpp: bpp)
        let replacement = rgbaBytes(from: newColor)
        if pixelsMatch(target, replacement, tolerance: 0) { return }

        let tolerance: Int32 = 16
        var stack: [(Int, Int)] = [(sx, sy)]
        while let (x, y) = stack.popLast() {
            var xl = x
            while xl >= 0,
                  pixelsMatch(pixel(data: data, x: xl, y: y, row: bytesPerRow, bpp: bpp), target, tolerance: tolerance) {
                xl -= 1
            }
            var xr = x + 1
            while xr < w,
                  pixelsMatch(pixel(data: data, x: xr, y: y, row: bytesPerRow, bpp: bpp), target, tolerance: tolerance) {
                xr += 1
            }
            let left = xl + 1
            let right = xr - 1
            guard left <= right else { continue }

            for fx in left...right {
                setPixel(data: data, x: fx, y: y, row: bytesPerRow, bpp: bpp, color: replacement)
            }
            for ny in [y - 1, y + 1] where ny >= 0 && ny < h {
                var inSpan = false
                for fx in left...right {
                    let match = pixelsMatch(pixel(data: data, x: fx, y: ny, row: bytesPerRow, bpp: bpp), target, tolerance: tolerance)
                    if match && !inSpan {
                        stack.append((fx, ny))
                        inSpan = true
                    } else if !match {
                        inSpan = false
                    }
                }
            }
        }
    }

    private static func pixel(data: UnsafeMutablePointer<UInt8>, x: Int, y: Int, row: Int, bpp: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        let p = data + y * row + x * bpp
        return (p[0], p[1], p[2], bpp >= 4 ? p[3] : 255)
    }

    private static func setPixel(data: UnsafeMutablePointer<UInt8>, x: Int, y: Int, row: Int, bpp: Int, color: (UInt8, UInt8, UInt8, UInt8)) {
        let p = data + y * row + x * bpp
        p[0] = color.0; p[1] = color.1; p[2] = color.2
        if bpp >= 4 { p[3] = color.3 }
    }

    private static func pixelsMatch(_ a: (UInt8, UInt8, UInt8, UInt8), _ b: (UInt8, UInt8, UInt8, UInt8), tolerance: Int32) -> Bool {
        if tolerance == 0 { return a == b }
        let dr = Int32(a.0) - Int32(b.0)
        let dg = Int32(a.1) - Int32(b.1)
        let db = Int32(a.2) - Int32(b.2)
        let da = Int32(a.3) - Int32(b.3)
        return abs(dr) <= tolerance && abs(dg) <= tolerance && abs(db) <= tolerance && abs(da) <= tolerance
    }

    private static func rgbaBytes(from color: NSColor) -> (UInt8, UInt8, UInt8, UInt8) {
        let c = color.usingColorSpace(.deviceRGB) ?? color
        return (
            UInt8(round(c.redComponent * 255)),
            UInt8(round(c.greenComponent * 255)),
            UInt8(round(c.blueComponent * 255)),
            UInt8(round(c.alphaComponent * 255))
        )
    }
}
