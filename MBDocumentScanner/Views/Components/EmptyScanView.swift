import SwiftUI

struct EmptyScanView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ScanDocumentIllustration()
                    .frame(height: 204)
                    .padding(.top, 6)

                Text("No documents")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ScanTheme.ink)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .scanCard(cornerRadius: 30)
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Drawn with native shapes so the artwork stays crisp at every display size.
struct ScanDocumentIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(ScanTheme.accentSoft)
                .frame(width: 210, height: 210)
            Circle()
                .strokeBorder(ScanTheme.accent.opacity(0.08), lineWidth: 1)
                .frame(width: 242, height: 242)

            RoundedRectangle(cornerRadius: 15)
                .fill(ScanTheme.accent.opacity(0.16))
                .frame(width: 124, height: 160)
                .rotationEffect(.degrees(-13))
                .offset(x: -14, y: 1)

            paper
                .rotationEffect(.degrees(7))
                .phaseAnimator(reduceMotion ? [false] : [false, true]) { content, phase in
                    content.offset(y: phase ? -5 : 3)
                } animation: { _ in
                    .easeInOut(duration: 3)
                }

            Image(systemName: "sparkle")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(ScanTheme.accent)
                .offset(x: 94, y: -73)
            Circle()
                .fill(ScanTheme.accent.opacity(0.4))
                .frame(width: 7, height: 7)
                .offset(x: -102, y: 62)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private var paper: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(ScanTheme.accent)
                .padding(.bottom, 8)
            Capsule().fill(ScanTheme.ink.opacity(0.2)).frame(width: 74, height: 5)
            Capsule().fill(ScanTheme.ink.opacity(0.10)).frame(height: 5)
            Capsule().fill(ScanTheme.ink.opacity(0.10)).frame(width: 59, height: 5)
            Capsule().fill(ScanTheme.accent.opacity(0.30)).frame(width: 42, height: 5)
        }
        .padding(21)
        .frame(width: 130, height: 170, alignment: .topLeading)
        .background(ScanTheme.surface, in: RoundedRectangle(cornerRadius: 15))
        .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(ScanTheme.border, lineWidth: 1) }
        .shadow(color: ScanTheme.ink.opacity(0.10), radius: 16, x: 0, y: 10)
    }
}
