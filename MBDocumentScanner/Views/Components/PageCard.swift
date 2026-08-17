import SwiftUI

struct PageCard: View {
    let page: ScannedPage
    let pageNumber: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                Image(uiImage: page.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .background(Color.white)
            }
            .aspectRatio(0.74, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)

            HStack(alignment: .firstTextBaseline) {
                Text("Page \(pageNumber)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                QualityBadge(quality: page.quality, compact: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

