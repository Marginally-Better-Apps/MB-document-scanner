import SwiftUI
import UIKit

/// System colors only. The app follows the system accent (blue) the way Notes,
/// Files and Settings do, and keeps color for what needs attention.
enum ScanTheme {
    static let accent = Color.accentColor
    static let accentSoft = Color.accentColor.opacity(0.14)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let ink = Color(uiColor: .label)
    static let secondaryInk = Color(uiColor: .secondaryLabel)
    static let tertiaryInk = Color(uiColor: .tertiaryLabel)
    static let border = Color(uiColor: .separator)
    static let fill = Color(uiColor: .tertiarySystemFill)
    /// Orange for symbols, and a deeper orange for text so it stays readable on white.
    static let warning = Color.orange
    static let warningText = adaptive(light: 0xB25000, dark: 0xFF9F0A)

    static let cornerRadius: CGFloat = 26

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

extension View {
    func scanCard(cornerRadius: CGFloat = ScanTheme.cornerRadius) -> some View {
        background(ScanTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// The one prominent action on a screen: Liquid Glass on iOS 26, a filled button before it.
    @ViewBuilder
    func prominentActionStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    /// Secondary actions beside a prominent one.
    @ViewBuilder
    func secondaryActionStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// The document subtitle under an inline title on iOS 26.
    @ViewBuilder
    func navigationSubtitleIfAvailable(_ subtitle: String) -> some View {
        if #available(iOS 26.0, *) {
            navigationSubtitle(subtitle)
        } else {
            self
        }
    }
}

/// An icon with its word beside it. Toolbars on iOS 26 reduce a `Label` to its icon;
/// the main actions keep their words so nobody has to guess.
struct ActionLabel: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            Text(title)
        }
        .font(.headline)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

/// A scanned page presented as paper: white, hairline edge, soft lift.
struct PaperImage: View {
    let image: UIImage
    var cornerRadius: CGFloat = 4

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.10), radius: 6, y: 2)
    }
}

extension ScanQualityState {
    var tint: Color {
        switch self {
        case .analyzing: ScanTheme.secondaryInk
        case .ready where needsReview: ScanTheme.warning
        case .ready: ScanTheme.secondaryInk
        }
    }
}

extension QualityCheck {
    /// One plain sentence for a warning, phrased for anyone.
    var plainHeadline: String {
        switch id {
        case "sharpness": "This page looks blurry."
        case "contrast": "This page looks faint."
        case "text": "Some words may be hard to read."
        case "resolution": "This page may look blurry when printed."
        case "image": "This page couldn’t be read."
        default: title
        }
    }
}

extension Int {
    var pageCountText: String {
        "\(self) \(self == 1 ? "page" : "pages")"
    }
}
