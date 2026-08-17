import SwiftUI

struct ScanLibraryRow: View {
    @ObservedObject var session: ScanSession

    var body: some View {
        HStack(spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 5) {
                Text(session.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(session.pages.count) \(session.pages.count == 1 ? "page" : "pages")")
                    Text("•")
                    Text(session.modifiedAt, style: .date)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if session.pagesNeedingReview > 0 {
                    Label(
                        "\(session.pagesNeedingReview) to review",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                } else if session.pages.contains(where: { $0.quality == .analyzing }) {
                    Label("Checking pages…", systemImage: "hourglass")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Label("Ready", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                }
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 5)
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
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 58, height: 74)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.07), radius: 3, y: 1)
        .clipped()
    }
}

