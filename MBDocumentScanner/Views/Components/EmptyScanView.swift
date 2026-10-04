import SwiftUI

struct EmptyScanView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            GridBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    ViewfinderCorners()
                        .stroke(ScanTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 148, height: 148)
                        .phaseAnimator(reduceMotion ? [false] : [false, true]) { content, phase in
                            content.scaleEffect(phase ? 1.04 : 1)
                        } animation: { _ in
                            .easeInOut(duration: 2.4)
                        }

                    paper
                }
                .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("No Scans")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(ScanTheme.ink)
                    Text("Scan a document, or import photos and PDFs.\nEverything stays on this device.")
                        .font(.subheadline)
                        .foregroundStyle(ScanTheme.secondaryInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(32)
            .padding(.bottom, 40)
        }
    }

    private var paper: some View {
        VStack(alignment: .leading, spacing: 7) {
            Capsule().fill(ScanTheme.tertiaryInk).frame(width: 34, height: 4)
            Capsule().fill(ScanTheme.fill).frame(height: 4)
            Capsule().fill(ScanTheme.fill).frame(height: 4)
            Capsule().fill(ScanTheme.fill).frame(width: 30, height: 4)
        }
        .padding(13)
        .frame(width: 74, height: 96, alignment: .topLeading)
        .background(ScanTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}
