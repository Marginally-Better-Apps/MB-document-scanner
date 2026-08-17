import SwiftUI

struct QualitySummaryCard: View {
    let quality: ScanQualityState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: quality.systemImage)
                    .font(.title2)
                    .foregroundStyle(summaryColor)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(quality.title)
                        .font(.headline)
                    if let score = quality.score {
                        Text("Scan quality \(score)%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Analyzing on device")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(16)

            if !quality.checks.isEmpty {
                Divider().padding(.leading, 62)

                ForEach(Array(quality.checks.enumerated()), id: \.element.id) { index, check in
                    QualityCheckRow(check: check)
                    if index < quality.checks.count - 1 {
                        Divider().padding(.leading, 62)
                    }
                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var summaryColor: Color {
        switch quality {
        case .analyzing: .secondary
        case .ready where quality.needsReview: .orange
        case .ready: .green
        }
    }
}

private struct QualityCheckRow: View {
    let check: QualityCheck

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: check.systemImage)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(check.title)
                    .font(.subheadline.weight(.medium))
                Text(check.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: check.passed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(check.passed ? Color.green : Color.orange)
                .accessibilityLabel(check.passed ? "Passed" : "Review")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}
