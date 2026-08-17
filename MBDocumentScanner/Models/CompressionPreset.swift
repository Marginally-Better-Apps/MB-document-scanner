import CoreGraphics

enum CompressionPreset: String, CaseIterable, Identifiable {
    case smaller
    case balanced
    case bestQuality

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smaller: "Smaller File"
        case .balanced: "Balanced"
        case .bestQuality: "Best Quality"
        }
    }

    var shortTitle: String {
        switch self {
        case .smaller: "Small"
        case .balanced: "Balanced"
        case .bestQuality: "Best"
        }
    }

    var detail: String {
        switch self {
        case .smaller: "Good for email and quick sharing"
        case .balanced: "Clear text with a moderate file size"
        case .bestQuality: "Keeps the most detail for archiving"
        }
    }

    var jpegQuality: CGFloat {
        switch self {
        case .smaller: 0.48
        case .balanced: 0.74
        case .bestQuality: 0.92
        }
    }

    var maximumPixelDimension: CGFloat {
        switch self {
        case .smaller: 1_600
        case .balanced: 2_400
        case .bestQuality: 4_096
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf
    case images

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pdf: "PDF"
        case .images: "JPEG Pages"
        }
    }

    var systemImage: String {
        switch self {
        case .pdf: "doc.richtext"
        case .images: "photo.on.rectangle.angled"
        }
    }
}

