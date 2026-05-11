import AppKit
import Foundation

/// Vector overlay on top of the rasterised bitmap. Each object stays
/// editable (move/resize/rotate/restyle/delete) until the user saves —
/// at save time the objects are flattened into a copy of the bitmap so
/// the exported file is a single composite.
struct PaintObject: Identifiable, Equatable {

    let id: UUID
    var kind: Kind
    var color: NSColor
    var lineWidth: CGFloat
    var fillShape: Bool
    /// Rotation about `center`, in radians. Only meaningful for
    /// rect/ellipse/text (line/arrow rotation is implicit in endpoints).
    var rotation: CGFloat

    enum Kind: Equatable {
        case text(origin: CGPoint, content: String, fontSize: CGFloat)
        case arrow(from: CGPoint, to: CGPoint)
        case line(from: CGPoint, to: CGPoint)
        case rect(rect: CGRect)
        case ellipse(rect: CGRect)
    }

    /// Identifier for each draggable handle on a selected object.
    enum Handle: Hashable {
        case start, end          // line/arrow endpoints
        case nw, n, ne, e, se, s, sw, w  // rect/ellipse resize
        case rotation
    }

    init(
        id: UUID = UUID(),
        kind: Kind,
        color: NSColor,
        lineWidth: CGFloat,
        fillShape: Bool = false,
        rotation: CGFloat = 0
    ) {
        self.id = id
        self.kind = kind
        self.color = color
        self.lineWidth = lineWidth
        self.fillShape = fillShape
        self.rotation = rotation
    }

    var isText: Bool {
        if case .text = kind { return true }
        return false
    }

    var supportsRotation: Bool {
        switch kind {
        case .text, .rect, .ellipse: return true
        case .line, .arrow:          return false
        }
    }

    // MARK: - Geometry

    /// Axis-aligned bbox in the object's local (unrotated) space.
    var localBBox: CGRect {
        switch kind {
        case .text(let origin, let content, let fontSize):
            let size = (content as NSString).size(
                withAttributes: [.font: NSFont.systemFont(ofSize: fontSize)]
            )
            return CGRect(
                x: origin.x, y: origin.y,
                width: max(size.width, 12), height: max(size.height, 12)
            )
        case .arrow(let a, let b), .line(let a, let b):
            return CGRect(
                x: min(a.x, b.x), y: min(a.y, b.y),
                width: max(abs(b.x - a.x), 1), height: max(abs(b.y - a.y), 1)
            )
        case .rect(let r), .ellipse(let r):
            return r
        }
    }

    var center: CGPoint {
        let b = localBBox
        return CGPoint(x: b.midX, y: b.midY)
    }

    /// World-space axis-aligned bbox (after rotation), padded so thin
    /// strokes are still easy to grab.
    var boundingBox: CGRect {
        let pad: CGFloat = max(8, lineWidth)
        let local = localBBox
        guard rotation != 0 else { return local.insetBy(dx: -pad, dy: -pad) }
        let corners = [
            CGPoint(x: local.minX, y: local.minY),
            CGPoint(x: local.maxX, y: local.minY),
            CGPoint(x: local.maxX, y: local.maxY),
            CGPoint(x: local.minX, y: local.maxY)
        ].map { Self.rotate($0, around: center, by: rotation) }
        let xs = corners.map(\.x), ys = corners.map(\.y)
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            .insetBy(dx: -pad, dy: -pad)
    }

    /// Body hit-test (in world coords). For shapes, inverse-rotates the
    /// point and tests against the local bbox; for line/arrow, uses
    /// distance to the line segment so a thin diagonal doesn't have a
    /// huge slack region around it.
    func contains(point worldP: CGPoint) -> Bool {
        let pad: CGFloat = max(8, lineWidth)
        switch kind {
        case .line(let a, let b), .arrow(let a, let b):
            return Self.distance(from: worldP, toSegmentFrom: a, to: b) <= pad
        case .text, .rect, .ellipse:
            let localP = rotation == 0
                ? worldP
                : Self.rotate(worldP, around: center, by: -rotation)
            return localBBox.insetBy(dx: -pad, dy: -pad).contains(localP)
        }
    }

    mutating func translate(by delta: CGSize) {
        switch kind {
        case .text(let origin, let content, let fs):
            kind = .text(
                origin: CGPoint(x: origin.x + delta.width, y: origin.y + delta.height),
                content: content, fontSize: fs
            )
        case .arrow(let a, let b):
            kind = .arrow(
                from: CGPoint(x: a.x + delta.width, y: a.y + delta.height),
                to: CGPoint(x: b.x + delta.width, y: b.y + delta.height)
            )
        case .line(let a, let b):
            kind = .line(
                from: CGPoint(x: a.x + delta.width, y: a.y + delta.height),
                to: CGPoint(x: b.x + delta.width, y: b.y + delta.height)
            )
        case .rect(let r):
            kind = .rect(rect: r.offsetBy(dx: delta.width, dy: delta.height))
        case .ellipse(let r):
            kind = .ellipse(rect: r.offsetBy(dx: delta.width, dy: delta.height))
        }
    }

    // MARK: - Handles

    /// Returns the handles available for this object in world coords.
    /// Order matters only for the rotation handle, which we keep last so
    /// hit-tests prefer resize handles when they overlap visually.
    func handlesInWorld() -> [(Handle, CGPoint)] {
        switch kind {
        case .line(let a, let b), .arrow(let a, let b):
            return [(.start, a), (.end, b)]
        case .rect, .ellipse:
            return shapeHandles(includeEdges: true)
        case .text:
            return shapeHandles(includeEdges: false)
        }
    }

    private func shapeHandles(includeEdges: Bool) -> [(Handle, CGPoint)] {
        let b = localBBox
        var local: [(Handle, CGPoint)] = [
            (.nw, CGPoint(x: b.minX, y: b.maxY)),
            (.ne, CGPoint(x: b.maxX, y: b.maxY)),
            (.se, CGPoint(x: b.maxX, y: b.minY)),
            (.sw, CGPoint(x: b.minX, y: b.minY))
        ]
        if includeEdges {
            local.append(contentsOf: [
                (.n, CGPoint(x: b.midX, y: b.maxY)),
                (.e, CGPoint(x: b.maxX, y: b.midY)),
                (.s, CGPoint(x: b.midX, y: b.minY)),
                (.w, CGPoint(x: b.minX, y: b.midY))
            ])
        }
        // Rotation knob — sits above the top edge, in the object's
        // local space, so it rotates along with the bbox.
        local.append((.rotation, CGPoint(x: b.midX, y: b.maxY + 28)))
        return local.map { (h, p) in
            (h, rotation == 0 ? p : Self.rotate(p, around: center, by: rotation))
        }
    }

    /// Apply a handle drag. `anchor` is the object's state at mouseDown
    /// so the math is referenced to a fixed origin (no compounding drift
    /// across frames).
    mutating func applyHandle(_ handle: Handle, world worldPoint: CGPoint, anchor: PaintObject) {
        switch handle {
        case .start:
            if case .line(_, let b) = anchor.kind { kind = .line(from: worldPoint, to: b) }
            if case .arrow(_, let b) = anchor.kind { kind = .arrow(from: worldPoint, to: b) }
        case .end:
            if case .line(let a, _) = anchor.kind { kind = .line(from: a, to: worldPoint) }
            if case .arrow(let a, _) = anchor.kind { kind = .arrow(from: a, to: worldPoint) }
        case .rotation:
            let dx = worldPoint.x - anchor.center.x
            let dy = worldPoint.y - anchor.center.y
            // Local rotation handle direction is (+y). atan2(dy,dx) gives
            // the world angle of (dy,dx); subtract π/2 so when the user
            // points straight up we get rotation = 0.
            rotation = atan2(dy, dx) - .pi / 2
        case .nw, .n, .ne, .e, .se, .s, .sw, .w:
            let localP = anchor.rotation == 0
                ? worldPoint
                : Self.rotate(worldPoint, around: anchor.center, by: -anchor.rotation)
            applyResize(handle: handle, localPoint: localP, anchor: anchor)
        }
    }

    private mutating func applyResize(handle: Handle, localPoint p: CGPoint, anchor: PaintObject) {
        var b = anchor.localBBox
        switch handle {
        case .nw: b = CGRect(x: p.x, y: b.minY, width: b.maxX - p.x, height: p.y - b.minY)
        case .n:  b = CGRect(x: b.minX, y: b.minY, width: b.width, height: p.y - b.minY)
        case .ne: b = CGRect(x: b.minX, y: b.minY, width: p.x - b.minX, height: p.y - b.minY)
        case .e:  b = CGRect(x: b.minX, y: b.minY, width: p.x - b.minX, height: b.height)
        case .se: b = CGRect(x: b.minX, y: p.y, width: p.x - b.minX, height: b.maxY - p.y)
        case .s:  b = CGRect(x: b.minX, y: p.y, width: b.width, height: b.maxY - p.y)
        case .sw: b = CGRect(x: p.x, y: p.y, width: b.maxX - p.x, height: b.maxY - p.y)
        case .w:  b = CGRect(x: p.x, y: b.minY, width: b.maxX - p.x, height: b.height)
        default:  return
        }
        b.size.width = max(b.size.width, 4)
        b.size.height = max(b.size.height, 4)
        switch anchor.kind {
        case .rect:    kind = .rect(rect: b)
        case .ellipse: kind = .ellipse(rect: b)
        case .text(_, let content, let oldFontSize):
            let oldBB = anchor.localBBox
            let scale = oldBB.height > 0 ? b.height / oldBB.height : 1
            let newFontSize = max(6, oldFontSize * scale)
            let newSize = (content as NSString).size(
                withAttributes: [.font: NSFont.systemFont(ofSize: newFontSize)]
            )
            // Pin the corner opposite the dragged one so the anchor
            // stays fixed and the text scales toward the drag direction.
            let originX: CGFloat
            let originY: CGFloat
            switch handle {
            case .nw, .sw: originX = b.maxX - newSize.width
            default:       originX = b.minX
            }
            switch handle {
            case .nw, .ne: originY = b.maxY - newSize.height
            default:       originY = b.minY
            }
            kind = .text(origin: CGPoint(x: originX, y: originY), content: content, fontSize: newFontSize)
        default:
            break
        }
    }

    // MARK: - Drawing

    func draw() {
        guard rotation != 0 else { drawUnrotated(); return }
        NSGraphicsContext.saveGraphicsState()
        let t = NSAffineTransform()
        t.translateX(by: center.x, yBy: center.y)
        t.rotate(byRadians: rotation)
        t.translateX(by: -center.x, yBy: -center.y)
        t.concat()
        drawUnrotated()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawUnrotated() {
        switch kind {
        case .text(let origin, let content, let fontSize):
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize),
                .foregroundColor: color
            ]
            (content as NSString).draw(at: origin, withAttributes: attrs)
        case .arrow(let a, let b):
            drawArrow(from: a, to: b)
        case .line(let a, let b):
            let path = NSBezierPath()
            path.move(to: a); path.line(to: b)
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            color.setStroke()
            path.stroke()
        case .rect(let r):
            let p = NSBezierPath(rect: r)
            p.lineWidth = lineWidth
            if fillShape { color.setFill(); p.fill() }
            color.setStroke(); p.stroke()
        case .ellipse(let r):
            let p = NSBezierPath(ovalIn: r)
            p.lineWidth = lineWidth
            if fillShape { color.setFill(); p.fill() }
            color.setStroke(); p.stroke()
        }
    }

    private func drawArrow(from a: CGPoint, to b: CGPoint) {
        let shaft = NSBezierPath()
        shaft.move(to: a); shaft.line(to: b)
        shaft.lineWidth = lineWidth
        shaft.lineCapStyle = .round
        color.setStroke()
        shaft.stroke()

        let headLen = max(lineWidth * 4, 14)
        let angle = atan2(b.y - a.y, b.x - a.x)
        let spread: CGFloat = .pi / 7
        let p1 = CGPoint(
            x: b.x - headLen * cos(angle - spread),
            y: b.y - headLen * sin(angle - spread)
        )
        let p2 = CGPoint(
            x: b.x - headLen * cos(angle + spread),
            y: b.y - headLen * sin(angle + spread)
        )
        let head = NSBezierPath()
        head.move(to: b)
        head.line(to: p1)
        head.line(to: p2)
        head.close()
        color.setFill()
        head.fill()
    }

    // MARK: - Math helpers

    private static func rotate(_ p: CGPoint, around c: CGPoint, by angle: CGFloat) -> CGPoint {
        let cosA = cos(angle), sinA = sin(angle)
        let dx = p.x - c.x, dy = p.y - c.y
        return CGPoint(x: c.x + dx * cosA - dy * sinA, y: c.y + dx * sinA + dy * cosA)
    }

    private static func distance(from p: CGPoint, toSegmentFrom a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq
        t = max(0, min(1, t))
        let projX = a.x + t * dx, projY = a.y + t * dy
        return hypot(p.x - projX, p.y - projY)
    }
}
