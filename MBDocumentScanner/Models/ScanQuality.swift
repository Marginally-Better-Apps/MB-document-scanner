import Foundation

enum ScanQualityState: Equatable, Codable {
    case analyzing
    case ready(score: Int, checks: [QualityCheck])

    var score: Int? {
        guard case let .ready(score, _) = self else { return nil }
        return score
    }

    var checks: [QualityCheck] {
        guard case let .ready(_, checks) = self else { return [] }
        return checks
    }

    var needsReview: Bool {
        guard case let .ready(score, checks) = self else { return false }
        return score < 72 || checks.contains(where: { !$0.passed && $0.isImportant })
    }

    var title: String {
        switch self {
        case .analyzing: "Checking scan…"
        case .ready where needsReview: "Needs Review"
        case .ready: "Looks Good"
        }
    }

    var systemImage: String {
        switch self {
        case .analyzing: "hourglass"
        case .ready where needsReview: "exclamationmark.triangle.fill"
        case .ready: "checkmark.circle.fill"
        }
    }
}

struct QualityCheck: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let detail: String
    let passed: Bool
    let isImportant: Bool
    let systemImage: String
}

struct PageAnalysis {
    let recognizedText: String
    let quality: ScanQualityState
}
