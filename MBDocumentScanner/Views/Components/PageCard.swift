import SwiftUI

struct PageCard: View {
    let page: ScannedPage
    let pageNumber: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GeometryReader { proxy in
                Image(uiImage: page.image)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .background(ScanTheme.background)
            }
            .aspectRatio(0.78, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Page \(pageNumber)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ScanTheme.ink)
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ScanTheme.secondaryInk)
                        .accessibilityHidden(true)
                }

                QualityBadge(quality: page.quality, compact: true)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .padding(10)
        .scanCard(cornerRadius: 22)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens page details and editing tools")
    }
}
