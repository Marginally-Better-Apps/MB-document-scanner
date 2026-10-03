import SwiftUI

struct ScanLibraryRow: View {
    @ObservedObject var session: ScanSession

    var body: some View {
        HStack(spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("\(pageCountText(session.pages.count)) · \(session.modifiedAt.formatted(.relative(presentation: .named)))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                status
                    .labelStyle(CompactLabelStyle())
                    .font(.caption.weight(.medium))
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var status: some View {
        if session.pagesNeedingReview > 0 {
            Label(
                "\(session.pagesNeedingReview) \(session.pagesNeedingReview == 1 ? "page needs" : "pages need") review",
                systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
        } else if session.isAnalyzing {
            Label(ScanQualityState.analyzing.title, systemImage: ScanQualityState.analyzing.systemImage)
                .foregroundStyle(.secondary)
        } else if !session.isEmpty {
            Label("Looks Good", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
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
        .frame(width: 56, height: 72)
        .clipped()
        .pageSurface(cornerRadius: 8)
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}
