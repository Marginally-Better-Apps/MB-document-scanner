import SwiftUI

struct QualityBadge: View {
    let quality: ScanQualityState
    var compact = false

    private var color: Color {
        switch quality {
        case .analyzing: .secondary
        case .ready where quality.needsReview: .orange
        case .ready: .green
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if case .analyzing = quality {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: quality.systemImage)
            }
            if !compact || quality.needsReview {
                Text(quality.title)
                    .lineLimit(1)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, compact ? 0 : 9)
        .padding(.vertical, compact ? 0 : 6)
        .background {
            if !compact {
                Capsule().fill(color.opacity(0.12))
            }
        }
    }
}

