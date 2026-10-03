import SwiftUI

struct QualitySummaryCard: View {
    let quality: ScanQualityState
    let onSetWarningDismissed: (String, Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: quality.systemImage)
                    .font(.title3)
                    .foregroundStyle(summaryColor)
                    .frame(width: 46, height: 46)
                    .background(summaryColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 15))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("SCAN QUALITY")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.1)
                        .foregroundStyle(ScanTheme.secondaryInk)
                    Text(quality.title)
                        .font(.headline)
                        .foregroundStyle(ScanTheme.ink)
                    Text(summaryDetail)
                        .font(.caption)
                        .foregroundStyle(ScanTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(18)

            if !quality.checks.isEmpty {
                Rectangle()
                    .fill(ScanTheme.border)
                    .frame(height: 1)
                    .padding(.horizontal, 18)

                VStack(spacing: 18) {
                    ForEach(quality.checks.filter { !$0.isDismissed }) { check in
                        QualityCheckRow(check: check) {
                            onSetWarningDismissed(check.id, true)
                        }
                    }

                    if !quality.dismissedWarnings.isEmpty {
                        DisclosureGroup {
                            VStack(spacing: 18) {
                                ForEach(quality.dismissedWarnings) { check in
                                    QualityCheckRow(check: check) {
                                        onSetWarningDismissed(check.id, false)
                                    }
                                }
                            }
                            .padding(.top, 12)
                        } label: {
                            Text("Dismissed warnings (\(quality.dismissedWarnings.count))")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ScanTheme.secondaryInk)
                        .tint(ScanTheme.secondaryInk)
                    }
                }
                .padding(18)
            }
        }
        .scanCard()
    }

    private var summaryDetail: String {
        if case .analyzing = quality { return "Analyzing on your device" }
        let count = quality.activeWarnings.count
        if count > 0 {
            return "\(count) \(count == 1 ? "warning" : "warnings") to review. Dismiss any you’re comfortable with."
        }
        if !quality.dismissedWarnings.isEmpty {
            return "All warnings cleared. Dismissed checks can be restored below."
        }
        if quality.needsVisualReview {
            return "Some checks need a visual review."
        }
        return "No issues found in the sampled text."
    }

    private var summaryColor: Color {
        switch quality {
        case .analyzing: ScanTheme.secondaryInk
        case .ready where quality.needsReview: .orange
        case .ready where quality.needsVisualReview: ScanTheme.secondaryInk
        case .ready: ScanTheme.accent
        }
    }
}

private struct QualityCheckRow: View {
    let check: QualityCheck
    let onToggleDismissed: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: check.systemImage)
                .font(.subheadline)
                .foregroundStyle(ScanTheme.secondaryInk)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(check.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ScanTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Image(systemName: statusImage)
                        .font(.subheadline)
                        .foregroundStyle(statusColor)
                        .accessibilityLabel(statusLabel)
                }
                Text(check.detail)
                    .font(.caption)
                    .foregroundStyle(ScanTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                if check.status == .warning {
                    Button(check.isDismissed ? "Restore warning" : "Dismiss warning", action: onToggleDismissed)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ScanTheme.accent)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(check.isDismissed ? "Restore" : "Dismiss") \(check.title) warning")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var statusLabel: String {
        if check.isDismissed { return "Dismissed" }
        switch check.status {
        case .passed: return "Passed"
        case .warning: return "Review"
        case .notEvaluated: return "Check visually"
        }
    }

    private var statusImage: String {
        if check.isDismissed { return "minus.circle" }
        switch check.status {
        case .passed: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .notEvaluated: return "info.circle"
        }
    }

    private var statusColor: Color {
        if check.isDismissed { return ScanTheme.secondaryInk }
        switch check.status {
        case .passed: return ScanTheme.accent
        case .warning: return .orange
        case .notEvaluated: return ScanTheme.secondaryInk
        }
    }
}
