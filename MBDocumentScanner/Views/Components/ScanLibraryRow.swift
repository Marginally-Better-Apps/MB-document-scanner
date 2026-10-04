import SwiftUI

struct ScanLibraryRow: View {
    @ObservedObject var session: ScanSession

    var body: some View {
        HStack(spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.body)
                    .foregroundStyle(ScanTheme.ink)
                    .lineLimit(2)

                Text("\(session.pages.count.pageCountText) · \(dateText)")
                    .font(.subheadline)
                    .foregroundStyle(ScanTheme.secondaryInk)

                if session.pagesNeedingReview > 0 {
                    Label("\(session.pagesNeedingReview.pageCountText) to check", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(ScanTheme.warningText)
                }
            }

            Spacer(minLength: 8)

            if session.pages.contains(where: { $0.quality == .analyzing }) {
                ProgressView()
                    .accessibilityLabel("Checking pages")
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var dateText: String {
        let date = session.modifiedAt
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var thumbnail: some View {
        ZStack {
            if let image = session.thumbnail {
                PaperImage(image: image, cornerRadius: 3)
            } else {
                Image(systemName: "doc")
                    .font(.title3)
                    .foregroundStyle(ScanTheme.tertiaryInk)
            }
        }
        .frame(width: 44, height: 56)
        .accessibilityHidden(true)
    }
}
