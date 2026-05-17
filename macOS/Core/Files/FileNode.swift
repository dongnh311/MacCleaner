import Foundation

struct FileNode: Identifiable, Hashable, Sendable {
    let id: URL
    let url: URL
    let name: String
    let size: Int64
    let isDirectory: Bool
    let lastModified: Date?

    var sizeText: String { size.formattedBytes }

    var category: FileCategory { FileCategory.classify(url: url, isDirectory: isDirectory) }
}

enum FileCategory: String, Sendable, Hashable, CaseIterable {
    case directory
    case document
    case media
    case code
    case archive
    case app
    case other

    var color: String {
        switch self {
        case .directory: return "directoryColor"
        case .document:  return "docColor"
        case .media:     return "mediaColor"
        case .code:      return "codeColor"
        case .archive:   return "archiveColor"
        case .app:       return "appColor"
        case .other:     return "otherColor"
        }
    }

    static func classify(url: URL, isDirectory: Bool) -> FileCategory {
        if isDirectory {
            if url.pathExtension == "app" { return .app }
            return .directory
        }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "md", "pages", "numbers", "key":
            return .document
        case "jpg", "jpeg", "png", "heic", "gif", "tiff", "tif", "raw", "cr2", "arw", "mp4", "mov", "m4v", "mkv", "avi", "wav", "mp3", "m4a", "aac", "flac", "ogg":
            return .media
        case "swift", "kt", "java", "py", "js", "ts", "tsx", "jsx", "rb", "go", "rs", "c", "cpp", "h", "hpp", "m", "mm", "cs", "html", "css", "scss", "json", "xml", "yaml", "yml", "sh", "bash", "zsh":
            return .code
        case "zip", "tar", "gz", "bz2", "xz", "7z", "rar", "dmg", "iso":
            return .archive
        case "ipa", "pkg":
            return .app
        default:
            return .other
        }
    }
}
