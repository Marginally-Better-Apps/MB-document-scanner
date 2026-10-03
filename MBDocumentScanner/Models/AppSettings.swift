import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    @Published var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance.rawValue) }
    }

    @Published var exportFormat: ExportFormat {
        didSet { defaults.set(exportFormat.rawValue, forKey: Key.exportFormat.rawValue) }
    }

    @Published var compression: CompressionPreset {
        didSet { defaults.set(compression.rawValue, forKey: Key.compression.rawValue) }
    }

    @Published var librarySortOrder: LibrarySortOrder {
        didSet { defaults.set(librarySortOrder.rawValue, forKey: Key.librarySortOrder.rawValue) }
    }

    @Published var usesLanguageCorrection: Bool {
        didSet { defaults.set(usesLanguageCorrection, forKey: Key.usesLanguageCorrection.rawValue) }
    }

    private let defaults: UserDefaults

    private enum Key: String, CaseIterable {
        case appearance = "settings.appearance"
        case exportFormat = "settings.exportFormat"
        case compression = "settings.compression"
        case librarySortOrder = "settings.librarySortOrder"
        case usesLanguageCorrection = "settings.usesLanguageCorrection"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Key.appearance.rawValue)
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
        exportFormat = defaults.string(forKey: Key.exportFormat.rawValue)
            .flatMap(ExportFormat.init(rawValue:)) ?? .pdf
        compression = defaults.string(forKey: Key.compression.rawValue)
            .flatMap(CompressionPreset.init(rawValue:)) ?? .balanced
        librarySortOrder = defaults.string(forKey: Key.librarySortOrder.rawValue)
            .flatMap(LibrarySortOrder.init(rawValue:)) ?? .recent
        usesLanguageCorrection = defaults.object(forKey: Key.usesLanguageCorrection.rawValue) as? Bool ?? true
    }

    func reset() {
        appearance = .system
        exportFormat = .pdf
        compression = .balanced
        librarySortOrder = .recent
        usesLanguageCorrection = true

        for key in Key.allCases {
            defaults.removeObject(forKey: key.rawValue)
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum LibrarySortOrder: String, CaseIterable, Identifiable {
    case recent
    case newest
    case oldest
    case title

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: "Recently Updated"
        case .newest: "Newest First"
        case .oldest: "Oldest First"
        case .title: "Title"
        }
    }

    @MainActor
    func sorted(_ documents: [ScanSession]) -> [ScanSession] {
        documents.sorted { lhs, rhs in
            switch self {
            case .recent:
                if lhs.modifiedAt != rhs.modifiedAt { return lhs.modifiedAt > rhs.modifiedAt }
            case .newest:
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            case .oldest:
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            case .title:
                let comparison = lhs.title.localizedStandardCompare(rhs.title)
                if comparison != .orderedSame { return comparison == .orderedAscending }
            }

            if lhs.modifiedAt != rhs.modifiedAt { return lhs.modifiedAt > rhs.modifiedAt }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
