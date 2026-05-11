import Foundation

enum PaintTool: String, CaseIterable, Identifiable, Sendable {
    case select
    case pencil
    case brush
    case eraser
    case fill
    case eyedropper
    case text
    case arrow
    case line
    case rectangle
    case ellipse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select:     return "Select"
        case .pencil:     return "Pencil"
        case .brush:      return "Brush"
        case .eraser:     return "Eraser"
        case .fill:       return "Fill"
        case .eyedropper: return "Eyedropper"
        case .text:       return "Text"
        case .arrow:      return "Arrow"
        case .line:       return "Line"
        case .rectangle:  return "Rectangle"
        case .ellipse:    return "Ellipse"
        }
    }

    var symbol: String {
        switch self {
        case .select:     return "cursorarrow"
        case .pencil:     return "pencil"
        case .brush:      return "paintbrush.pointed"
        case .eraser:     return "eraser"
        case .fill:       return "drop.fill"
        case .eyedropper: return "eyedropper"
        case .text:       return "textformat"
        case .arrow:      return "arrow.up.right"
        case .line:       return "line.diagonal"
        case .rectangle:  return "rectangle"
        case .ellipse:    return "circle"
        }
    }

    /// Drag-to-draw shapes that commit on mouseUp as vector objects.
    var isShape: Bool {
        self == .line || self == .rectangle || self == .ellipse || self == .arrow
    }

    /// Pixel-level operations that rasterise straight into the bitmap
    /// (and therefore can't be re-selected or re-edited individually).
    var isFreehand: Bool {
        self == .pencil || self == .brush || self == .eraser
    }
}
