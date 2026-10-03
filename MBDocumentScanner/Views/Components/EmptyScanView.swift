import SwiftUI

struct EmptyScanView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.accentColor.opacity(0.10))
                        .frame(width: 120, height: 120)

                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 56, weight: .regular))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                }
                .accessibilityHidden(true)

                Text("Scan Your First Document")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                Text("Capture clean pages, recognize text, check scan quality, and export—entirely on your device.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 14) {
                    tip("Tap **Scan Document** below to use the camera.", systemImage: "doc.viewfinder")
                    tip("Use \(Image(systemName: "square.and.arrow.down")) to import a PDF or paste an image.", systemImage: "doc.badge.plus")
                    tip("Scans stay on this iPhone. No account needed.", systemImage: "lock.fill")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
                .padding(.top, 28)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
    }

    private func tip(_ text: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .frame(width: 24)
        }
    }
}
