import Foundation
import UniformTypeIdentifiers

/// Supported export formats for a screenshot.
enum SaveFormat: String, CaseIterable {
    case png
    case jpeg
    case pdf

    var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .pdf: return "PDF"
        }
    }

    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .pdf: return "pdf"
        }
    }

    var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .pdf: return .pdf
        }
    }
}

/// Lightweight UserDefaults-backed app settings.
enum AppSettings {
    static let defaultSaveFormatKey = "defaultSaveFormat"

    static var defaultSaveFormat: SaveFormat {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultSaveFormatKey)
            return raw.flatMap(SaveFormat.init(rawValue:)) ?? .png
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultSaveFormatKey)
        }
    }
}
