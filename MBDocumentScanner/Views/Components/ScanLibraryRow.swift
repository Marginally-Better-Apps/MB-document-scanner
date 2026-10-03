import SwiftUI

struct ScanLibraryRow: View {
    @ObservedObject var session: ScanSession

    var body: some View {
        HStack(spacing: 16) {
            thumbnail

            VStack(alignment: .leading, spacing: 7) {
                Text(session.title)
                    .font(.headline)
                    .foregroundStyle(ScanTheme.ink)
                    .lineLimit(2)

                Text("\(session.pages.count) \(session.pages.count == 1 ? "page" : "pages") • \(session.modifiedAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(ScanTheme.secondaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

                if session.pagesNeedingReview > 0 {
                    Label(
                        "\(session.pagesNeedingReview) to review",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                } else if session.pages.contains(where: { $0.quality == .analyzing }) {
                    Label("Checking pages…", systemImage: "hourglass")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ScanTheme.secondaryInk)
                } else if session.pages.contains(where: { $0.quality.needsVisualReview }) {
                    Label("Check visually", systemImage: "eye")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ScanTheme.secondaryInk)
                } else {
                    Label("Ready", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ScanTheme.accent)
                }
            }
            .labelStyle(ScanStatusLabelStyle())

            Spacer(minLength: 4)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var thumbnail: some View {
        Group {
            if let image = session.thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc")
                    .font(.title2)
                    .foregroundStyle(ScanTheme.secondaryInk)
            }
        }
        .frame(width: 56, height: 72)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(ScanTheme.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
        .padding(11)
        .background(ScanTheme.accentSoft.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ScanStatusLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}
