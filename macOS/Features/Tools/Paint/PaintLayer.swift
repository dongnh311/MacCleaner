import AppKit
import Foundation

/// One layer of the document. Each layer has its own raster bitmap and
/// vector overlay; the canvas renders them bottom-to-top with the
/// vectors of layer N sitting between bitmap N and bitmap N+1.
@MainActor
final class PaintLayer: Identifiable {
    let id: UUID
    var name: String
    var bitmap: NSBitmapImageRep
    var objects: [PaintObject] = []
    var isVisible: Bool = true
    /// Bumped on every bitmap/objects mutation. PaintState compares this
    /// across consecutive undo snapshots and reuses the previous
    /// encoded PNG bytes for layers that haven't moved — without this,
    /// every action re-encodes every layer, which costs O(layers × 4MP).
    var revision: UInt64 = 0

    init(id: UUID = UUID(), name: String, size: CGSize) {
        self.id = id
        self.name = name
        self.bitmap = PaintLayer.makeClearedBitmap(size: size)
    }

    /// `NSBitmapImageRep` doesn't promise zeroed memory — explicitly
    /// memset so a fresh layer starts truly transparent rather than
    /// holding garbage RGBA bytes.
    static func makeClearedBitmap(size: CGSize) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        )!
        rep.size = size
        if let data = rep.bitmapData {
            memset(data, 0, rep.bytesPerRow * Int(size.height))
        }
        return rep
    }
}
