import SwiftUI

struct QualityBadge: View {
    let quality: ScanQualityState
    var compact = false

    private var color: Color {
        switch quality {
        case .analyzing: ScanTheme.secondaryInk
        case .ready where quality.needsReview: .orange
        case .ready where quality.needsVisualReview: ScanTheme.secondaryInk
        case .ready: ScanTheme.accent
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            if case .analyzing = quality {
                ProgressView()
                    .controlSize(.mini)
                    .tint(color)
            } else {
                Image(systemName: quality.systemImage)
            }
            Text(quality.title)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(color)
        .padding(.horizontal, compact ? 0 : 10)
        .padding(.vertical, compact ? 0 : 7)
        .background {
            if !compact {
                Capsule().fill(color.opacity(0.1))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(quality.title)
    }
}
