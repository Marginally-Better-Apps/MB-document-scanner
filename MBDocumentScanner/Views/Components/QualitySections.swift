import SwiftUI

/// Scan checks as grouped list sections: active checks, then any dismissed warnings.
struct QualitySections: View {
    let quality: ScanQualityState
    let onSetWarningDismissed: (String, Bool) -> Void

    var body: some View {
        Section {
            if case .analyzing = quality {
                HStack(spacing: 12) {
                    ProgressView()
                        .frame(width: 30, height: 30)
                    Text("Checking scan on device…")
                        .foregroundStyle(ScanTheme.secondaryInk)
                }
            } else {
                ForEach(quality.checks.filter { !$0.isDismissed }) { check in
                    QualityCheckRow(check: check) {
                        onSetWarningDismissed(check.id, true)
                    }
                }
            }
        } header: {
            Text("Scan Quality")
        } footer: {
            Text(summaryFooter)
        }

        if !quality.dismissedWarnings.isEmpty {
            Section {
                ForEach(quality.dismissedWarnings) { check in
                    QualityCheckRow(check: check) {
                        onSetWarningDismissed(check.id, false)
                    }
                }
            } header: {
                Text("Dismissed")
            }
        }
    }

    private var summaryFooter: String {
        if case .analyzing = quality { return "Text and sharpness are checked privately on this device." }
        let count = quality.activeWarnings.count
        if count > 0 {
            return "Rescan or crop to fix \(count == 1 ? "this warning" : "these warnings"), or dismiss \(count == 1 ? "it" : "them") if the page reads well."
        }
        if !quality.dismissedWarnings.isEmpty { return "All warnings dismissed." }
        if quality.needsVisualReview { return "Some checks need a quick look." }
        return "No issues found in the sampled text."
    }
}

private struct QualityCheckRow: View {
    let check: QualityCheck
    let onToggleDismissed: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SettingsIcon(check.systemImage, color: iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(check.title)
                    .foregroundStyle(ScanTheme.ink)
                Text(check.detail)
                    .font(.subheadline)
                    .foregroundStyle(ScanTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)

            Spacer(minLength: 8)

            if check.status == .warning {
                Button(check.isDismissed ? "Restore" : "Dismiss", action: onToggleDismissed)
                    .font(.subheadline.weight(.medium))
                    .buttonStyle(.borderless)
                    .padding(.top, 4)
                    .accessibilityLabel("\(check.isDismissed ? "Restore" : "Dismiss") \(check.title) warning")
            } else {
                Image(systemName: statusImage)
                    .font(.body)
                    .foregroundStyle(statusColor)
                    .padding(.top, 5)
                    .accessibilityLabel(statusLabel)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
    }

    private var iconColor: Color {
        if check.isDismissed { return .gray }
        switch check.status {
        case .passed: return ScanTheme.accent
        case .warning: return ScanTheme.warning
        case .notEvaluated: return .gray
        }
    }

    private var statusLabel: String {
        switch check.status {
        case .passed: return "Passed"
        case .warning: return "Review"
        case .notEvaluated: return "Check visually"
        }
    }

    private var statusImage: String {
        switch check.status {
        case .passed: return "checkmark"
        case .warning: return "exclamationmark"
        case .notEvaluated: return "eye"
        }
    }

    private var statusColor: Color {
        switch check.status {
        case .passed: return ScanTheme.accent
        case .warning: return ScanTheme.warning
        case .notEvaluated: return ScanTheme.tertiaryInk
        }
    }
}
