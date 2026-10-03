import SwiftUI

struct QualityBadge: View {
    let quality: ScanQualityState
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            if case .analyzing = quality {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: quality.systemImage)
            }
            if !compact || quality.needsReview {
                Text(compact ? "Review" : quality.title)
                    .lineLimit(1)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(quality.tintColor)
        .padding(.horizontal, compact ? 0 : 9)
        .padding(.vertical, compact ? 0 : 6)
        .background {
            if !compact {
                Capsule().fill(quality.tintColor.opacity(0.12))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(quality.title)
    }
}
