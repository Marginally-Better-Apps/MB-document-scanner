import SwiftUI

struct PageCard: View {
    let page: ScannedPage
    let pageNumber: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.white
                .aspectRatio(0.74, contentMode: .fit)
                .overlay {
                    Image(uiImage: page.image)
                        .resizable()
                        .scaledToFit()
                }
                .pageSurface()

            HStack(alignment: .firstTextBaseline) {
                Text("Page \(pageNumber)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                QualityBadge(quality: page.quality, compact: true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
