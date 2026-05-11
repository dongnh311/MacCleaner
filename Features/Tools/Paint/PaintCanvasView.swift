import AppKit
import SwiftUI

/// Wraps `PaintCanvasNSView`. The NSView reads its bitmap + object list
/// straight from `PaintState`; SwiftUI re-renders when `state.version`
/// bumps (via the @ObservedObject).
struct PaintCanvasView: NSViewRepresentable {

    @ObservedObject var state: PaintState

    func makeNSView(context: Context) -> PaintCanvasNSView {
        let view = PaintCanvasNSView(state: state)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    func updateNSView(_ nsView: PaintCanvasNSView, context: Context) {
        nsView.state = state
        let scaled = CGSize(
            width: state.canvasSize.width * state.zoom,
            height: state.canvasSize.height * state.zoom
        )
        if nsView.frame.size != scaled {
            nsView.frame.size = scaled
        }
        nsView.needsDisplay = true
    }
}

final class PaintCanvasNSView: NSView {

    var state: PaintState

    private var dragStart: CGPoint?
    private var dragCurrent: CGPoint?
    private var lastFreehandPoint: CGPoint?
    /// Tracks select-tool drag: last bitmap-space point for incremental
    /// translation, so we move by deltas rather than re-anchoring.
    private var lastSelectPoint: CGPoint?
    /// Active handle drag — populated at mouseDown if the user grabbed a
    /// resize/rotation handle of the currently selected object.
    private var draggedHandle: PaintObject.Handle?
    /// Object snapshot at mouseDown — applyHandle math references this so
    /// resize/rotate stays stable across frames.
    private var dragAnchor: PaintObject?

    init(state: PaintState) {
        self.state = state
        super.init(frame: NSRect(origin: .zero, size: state.canvasSize))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    // MARK: - Rendering

    override func draw(_ dirtyRect: NSRect) {
        let z = state.zoom
        drawCheckerBackdrop(in: dirtyRect)
        NSGraphicsContext.current?.imageInterpolation = z >= 2 ? .none : .high

        // Composite layers bottom-to-top. Each layer's vectors sit on top
        // of its own raster, but under the next layer's raster — so we
        // push/pop the zoom transform once per layer.
        for layer in state.layers where layer.isVisible {
            layer.bitmap.draw(in: bounds)
            if !layer.objects.isEmpty {
                NSGraphicsContext.saveGraphicsState()
                let transform = NSAffineTransform()
                transform.scale(by: z)
                transform.concat()
                for obj in layer.objects { obj.draw() }
                NSGraphicsContext.restoreGraphicsState()
            }
        }

        // Selected-object highlight + handles.
        if let obj = state.selectedObject {
            drawSelectionChrome(for: obj, zoom: z)
        }

        // Live shape preview for arrow/line/rect/ellipse drag.
        if state.tool.isShape, let s = dragStart, let c = dragCurrent {
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.scale(by: z)
            transform.concat()
            let preview = PaintObject(
                kind: shapeKind(from: s, to: c, tool: state.tool),
                color: state.nsColor.withAlphaComponent(0.75),
                lineWidth: state.brushSize,
                fillShape: state.fillShapes
            )
            preview.draw()
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    // MARK: - Transparent-canvas checker backdrop

    /// Paint S-style checkerboard so transparent regions read as
    /// "transparent" rather than "the window backdrop". Tile size is
    /// fixed in view-space so zoom doesn't change its visual scale.
    private func drawCheckerBackdrop(in rect: NSRect) {
        let tile: CGFloat = 12
        let startCol = Int(floor(rect.minX / tile))
        let endCol = Int(ceil(rect.maxX / tile))
        let startRow = Int(floor(rect.minY / tile))
        let endRow = Int(ceil(rect.maxY / tile))
        let light = NSColor(white: 0.86, alpha: 1)
        let dark = NSColor(white: 0.72, alpha: 1)
        for r in startRow..<endRow {
            for c in startCol..<endCol {
                ((r + c) % 2 == 0 ? light : dark).setFill()
                NSRect(x: CGFloat(c) * tile, y: CGFloat(r) * tile, width: tile, height: tile).fill()
            }
        }
    }

    // MARK: - Selection chrome

    /// Pixel radius (in view-space) for the visible handle dots + their
    /// click-hit area. Stays constant regardless of zoom so handles are
    /// always easy to grab.
    private let handleRadiusView: CGFloat = 5

    private func drawSelectionChrome(for obj: PaintObject, zoom z: CGFloat) {
        // Bounding box outline — axis-aligned in world coords, scaled to
        // view-space.
        let bbox = obj.boundingBox
        let viewRect = NSRect(
            x: bbox.origin.x * z, y: bbox.origin.y * z,
            width: bbox.size.width * z, height: bbox.size.height * z
        )
        NSColor.controlAccentColor.withAlphaComponent(0.6).setStroke()
        let dash = NSBezierPath(rect: viewRect)
        dash.setLineDash([5, 3], count: 2, phase: 0)
        dash.lineWidth = 1
        dash.stroke()

        // Handles — small white squares with accent border; rotation knob
        // is a circle drawn with a short tether line to the top edge so
        // its purpose is visually distinct from the resize handles.
        for (handle, worldPos) in obj.handlesInWorld() {
            let viewPos = NSPoint(x: worldPos.x * z, y: worldPos.y * z)
            if handle == .rotation {
                // Tether from top-center of bbox to the rotation knob.
                let topCenterLocal = CGPoint(x: obj.localBBox.midX, y: obj.localBBox.maxY)
                let topCenterWorld = obj.rotation == 0
                    ? topCenterLocal
                    : rotatePoint(topCenterLocal, around: obj.center, by: obj.rotation)
                let tether = NSBezierPath()
                tether.move(to: NSPoint(x: topCenterWorld.x * z, y: topCenterWorld.y * z))
                tether.line(to: viewPos)
                NSColor.controlAccentColor.withAlphaComponent(0.6).setStroke()
                tether.lineWidth = 1
                tether.stroke()
                let r = handleRadiusView + 1
                let circle = NSBezierPath(ovalIn: NSRect(
                    x: viewPos.x - r, y: viewPos.y - r,
                    width: r * 2, height: r * 2
                ))
                NSColor.white.setFill(); circle.fill()
                NSColor.controlAccentColor.setStroke(); circle.lineWidth = 1.5; circle.stroke()
            } else {
                let r = handleRadiusView
                let box = NSRect(
                    x: viewPos.x - r, y: viewPos.y - r,
                    width: r * 2, height: r * 2
                )
                NSColor.white.setFill()
                NSColor.controlAccentColor.setStroke()
                let path = NSBezierPath(rect: box)
                path.fill()
                path.lineWidth = 1.5
                path.stroke()
            }
        }
    }

    /// Returns the handle under `viewPoint` if any. View-space hit-test
    /// keeps the grab radius constant regardless of zoom.
    private func handleHit(at viewPoint: CGPoint, for obj: PaintObject) -> PaintObject.Handle? {
        let z = max(state.zoom, 0.0001)
        let radius = handleRadiusView + 3 // be generous for click target
        for (handle, worldPos) in obj.handlesInWorld() {
            let vp = CGPoint(x: worldPos.x * z, y: worldPos.y * z)
            if hypot(viewPoint.x - vp.x, viewPoint.y - vp.y) <= radius {
                return handle
            }
        }
        return nil
    }

    private func rotatePoint(_ p: CGPoint, around c: CGPoint, by angle: CGFloat) -> CGPoint {
        let cosA = cos(angle), sinA = sin(angle)
        let dx = p.x - c.x, dy = p.y - c.y
        return CGPoint(x: c.x + dx * cosA - dy * sinA, y: c.y + dx * sinA + dy * cosA)
    }

    // MARK: - Coordinate conversion

    private func bitmapPoint(from event: NSEvent) -> CGPoint {
        let v = convert(event.locationInWindow, from: nil)
        let z = max(state.zoom, 0.0001)
        return CGPoint(x: v.x / z, y: v.y / z)
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let p = bitmapPoint(from: event)
        window?.makeFirstResponder(self) // so keyDown (Delete) reaches us
        switch state.tool {
        case .select:
            let viewPoint = convert(event.locationInWindow, from: nil)
            // 1) Handle drag wins over body click — if user grabbed a
            //    handle of the currently selected object, start resize/
            //    rotate without changing selection.
            if let selected = state.selectedObject,
               let handle = handleHit(at: viewPoint, for: selected) {
                state.pushUndo(handle == .rotation ? "Rotate" : "Resize")
                draggedHandle = handle
                dragAnchor = selected
                return
            }
            // 2) Double-click text object → edit content.
            if event.clickCount >= 2,
               let obj = state.allVisibleObjects().reversed().first(where: { $0.contains(point: p) }),
               case .text(_, let content, let fontSize) = obj.kind {
                state.selectedID = obj.id
                if let edited = TextPrompt.show(initial: content) {
                    state.updateSelected { o in
                        if case .text(let origin, _, _) = o.kind {
                            o.kind = .text(origin: origin, content: edited, fontSize: fontSize)
                        }
                    }
                }
                return
            }
            // 3) Body click → select / start move.
            state.selectObject(at: p)
            lastSelectPoint = state.selectedID != nil ? p : nil
            if lastSelectPoint != nil { state.pushUndo("Move Object") }
            needsDisplay = true
        case .eyedropper:
            state.pickColor(at: p)
        case .fill:
            state.pushUndo("Fill")
            FloodFill.fill(bitmap: state.bitmap, at: p, with: state.nsColor)
            state.objectWillChange.send()
            needsDisplay = true
        case .pencil, .brush, .eraser:
            let label = state.tool == .pencil ? "Pencil" : state.tool == .brush ? "Brush" : "Erase"
            state.pushUndo(label)
            lastFreehandPoint = p
            stampFreehand(from: p, to: p)
        case .text:
            if let content = TextPrompt.show(initial: ""), !content.isEmpty {
                let obj = PaintObject(
                    kind: .text(origin: p, content: content, fontSize: state.fontSize),
                    color: state.nsColor,
                    lineWidth: 1
                )
                state.addObject(obj)
                needsDisplay = true
            }
        case .arrow, .line, .rectangle, .ellipse:
            dragStart = p
            dragCurrent = p
            needsDisplay = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let p = bitmapPoint(from: event)
        switch state.tool {
        case .select:
            // Handle drag takes priority over body drag (move).
            if let handle = draggedHandle, let anchor = dragAnchor {
                state.applyHandleToSelected(handle, world: p, anchor: anchor)
                needsDisplay = true
                return
            }
            guard let last = lastSelectPoint else { return }
            state.moveSelected(by: CGSize(width: p.x - last.x, height: p.y - last.y))
            lastSelectPoint = p
            needsDisplay = true
        case .pencil, .brush, .eraser:
            if let last = lastFreehandPoint { stampFreehand(from: last, to: p) }
            lastFreehandPoint = p
        case .arrow, .line, .rectangle, .ellipse:
            dragCurrent = p
            needsDisplay = true
        case .eyedropper, .fill, .text:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        let p = bitmapPoint(from: event)
        switch state.tool {
        case .select:
            lastSelectPoint = nil
            draggedHandle = nil
            dragAnchor = nil
        case .pencil, .brush, .eraser:
            lastFreehandPoint = nil
        case .arrow, .line, .rectangle, .ellipse:
            if let s = dragStart, hypot(p.x - s.x, p.y - s.y) > 1 {
                let obj = PaintObject(
                    kind: shapeKind(from: s, to: p, tool: state.tool),
                    color: state.nsColor,
                    lineWidth: state.brushSize,
                    fillShape: state.fillShapes
                )
                state.addObject(obj)
            }
            dragStart = nil
            dragCurrent = nil
            needsDisplay = true
        case .eyedropper, .fill, .text:
            break
        }
    }

    // MARK: - Pinch / Cmd+scroll zoom

    override func magnify(with event: NSEvent) {
        let next = state.zoom * (1 + event.magnification)
        state.zoom = min(max(next, PaintState.zoomRange.lowerBound), PaintState.zoomRange.upperBound)
    }

    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else {
            super.scrollWheel(with: event)
            return
        }
        let next = state.zoom * (1 + event.scrollingDeltaY * 0.01)
        state.zoom = min(max(next, PaintState.zoomRange.lowerBound), PaintState.zoomRange.upperBound)
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        // Delete / Backspace — remove the selected vector object.
        let chars = event.charactersIgnoringModifiers ?? ""
        if chars == "\u{7F}" || chars == "\u{08}" {
            if state.selectedID != nil {
                state.deleteSelected()
                needsDisplay = true
                return
            }
        }
        super.keyDown(with: event)
    }

    // MARK: - Drawing helpers (bitmap-space)

    private func stampFreehand(from a: CGPoint, to b: CGPoint) {
        state.withGraphicsContext {
            let path = NSBezierPath()
            path.move(to: a)
            path.line(to: b)
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.lineWidth = state.tool == .pencil ? max(1, state.brushSize * 0.4) : state.brushSize
            if state.tool == .eraser {
                // Truly clear the pixels to alpha 0 — the checker pattern
                // backdrop reveals the now-transparent area underneath.
                NSGraphicsContext.current?.compositingOperation = .clear
                NSColor.black.setStroke()
                path.stroke()
            } else {
                state.nsColor.setStroke()
                path.stroke()
            }
        }
        needsDisplay = true
    }

    private func shapeKind(from a: CGPoint, to b: CGPoint, tool: PaintTool) -> PaintObject.Kind {
        let rect = CGRect(
            x: min(a.x, b.x), y: min(a.y, b.y),
            width: abs(b.x - a.x), height: abs(b.y - a.y)
        )
        switch tool {
        case .arrow:     return .arrow(from: a, to: b)
        case .line:      return .line(from: a, to: b)
        case .rectangle: return .rect(rect: rect)
        case .ellipse:   return .ellipse(rect: rect)
        default:         return .line(from: a, to: b)
        }
    }
}

/// Modal NSAlert with a text field accessory — used by Text tool (new
/// object) and Select tool (double-click to edit). Synchronous so the
/// call site stays straight-line.
enum TextPrompt {
    @MainActor
    static func show(initial: String) -> String? {
        let alert = NSAlert()
        alert.messageText = initial.isEmpty ? "Add Text" : "Edit Text"
        alert.informativeText = "Type the text to place on the canvas."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = initial
        alert.accessoryView = field
        // Focus the text field so the user can type immediately.
        DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        let response = alert.runModal()
        return response == .alertFirstButtonReturn ? field.stringValue : nil
    }
}
