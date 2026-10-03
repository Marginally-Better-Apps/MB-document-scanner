import Foundation

enum ScanQualityState: Equatable, Codable {
    case analyzing
    // The old encoded `score` is ignored when reading existing documents.
    case ready(checks: [QualityCheck])

    var checks: [QualityCheck] {
        guard case let .ready(checks) = self else { return [] }
        return checks
    }

    var activeWarnings: [QualityCheck] {
        checks.filter { $0.status == .warning && !$0.isDismissed }
    }

    var dismissedWarnings: [QualityCheck] {
        checks.filter { $0.status == .warning && $0.isDismissed }
    }

    var needsReview: Bool { !activeWarnings.isEmpty }

    var needsVisualReview: Bool {
        !needsReview && dismissedWarnings.isEmpty && checks.contains(where: { $0.status == .notEvaluated })
    }

    var title: String {
        switch self {
        case .analyzing: "Checking scan…"
        case .ready where needsReview: "Needs Review"
        case .ready where !dismissedWarnings.isEmpty: "Reviewed"
        case .ready where needsVisualReview: "Check Visually"
        case .ready: "Looks Good"
        }
    }

    var systemImage: String {
        switch self {
        case .analyzing: "hourglass"
        case .ready where needsReview: "exclamationmark.triangle.fill"
        case .ready where !dismissedWarnings.isEmpty: "checkmark.circle"
        case .ready where needsVisualReview: "eye"
        case .ready: "checkmark.circle.fill"
        }
    }

    func settingDismissed(_ dismissed: Bool, for checkID: String) -> ScanQualityState {
        guard case let .ready(checks) = self else { return self }
        return .ready(checks: checks.map { check in
            var updated = check
            if check.id == checkID && check.status == .warning {
                updated.isDismissed = dismissed
            }
            return updated
        })
    }
}

struct QualityCheck: Identifiable, Equatable, Codable {
    enum Status: String, Codable {
        case passed
        case warning
        case notEvaluated
    }

    let id: String
    let title: String
    let detail: String
    let status: Status
    let systemImage: String
    var isDismissed: Bool = false

    init(id: String, title: String, detail: String, status: Status, systemImage: String, isDismissed: Bool = false) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
        self.systemImage = systemImage
        self.isDismissed = status == .warning && isDismissed
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, detail, status, systemImage, isDismissed
        case passed // Legacy documents used a Boolean and an `isImportant` flag.
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        detail = try container.decode(String.self, forKey: .detail)
        systemImage = try container.decode(String.self, forKey: .systemImage)
        if let storedStatus = try container.decodeIfPresent(Status.self, forKey: .status) {
            status = storedStatus
        } else {
            status = try container.decode(Bool.self, forKey: .passed) ? .passed : .warning
        }
        let storedDismissal = try container.decodeIfPresent(Bool.self, forKey: .isDismissed) ?? false
        isDismissed = status == .warning && storedDismissal
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(detail, forKey: .detail)
        try container.encode(status, forKey: .status)
        try container.encode(systemImage, forKey: .systemImage)
        try container.encode(isDismissed, forKey: .isDismissed)
    }
}

struct PageAnalysis {
    let recognizedText: String
    let quality: ScanQualityState
}
