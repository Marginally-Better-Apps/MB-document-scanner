import SwiftUI
import UIKit

/// System materials and one accent drawn from the app icon. Grouped backgrounds
/// go pure black in Dark Mode, the same canvas Settings and Compass use.
enum ScanTheme {
    static let accent = adaptive(light: 0x0A8A7A, dark: 0x3FCBB2)
    static let accentSoft = accent.opacity(0.14)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let ink = Color(uiColor: .label)
    static let secondaryInk = Color(uiColor: .secondaryLabel)
    static let tertiaryInk = Color(uiColor: .tertiaryLabel)
    static let border = Color(uiColor: .separator)
    static let fill = Color(uiColor: .tertiarySystemFill)
    static let primaryFill = accent
    /// Text on the accent fill: white on the deep light-mode teal, black on the bright dark-mode one.
    static let onAccent = adaptive(light: 0xFFFFFF, dark: 0x000000)
    static let warning = Color.orange

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

    /// Liquid Glass on iOS 26, a thick material before it.
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: Capsule())
        } else {
            background(.regularMaterial, in: Capsule())
                .overlay { Capsule().strokeBorder(ScanTheme.border.opacity(0.5), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        }
    }
}

struct ScanPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(ScanTheme.onAccent)
            .padding(.horizontal, 22)
            .frame(minHeight: 52)
            .background(ScanTheme.primaryFill, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct ScanSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(ScanTheme.accent)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(ScanTheme.fill, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// The white-glyph rounded square used throughout Settings.
struct SettingsIcon: View {
    let systemImage: String
    let color: Color

    init(_ systemImage: String, color: Color) {
        self.systemImage = systemImage
        self.color = color
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A row title with a Settings-style icon.
struct SettingsLabel: View {
    let title: String
    let systemImage: String
    let color: Color

    init(_ title: String, systemImage: String, color: Color) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
    }

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(ScanTheme.ink)
        } icon: {
            SettingsIcon(systemImage, color: color)
        }
    }
}

/// A floating capsule of actions, modeled on the Measure and Level switcher.
struct FloatingActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 4) {
            content
        }
        .padding(5)
        .glassCapsule()
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }
}

/// An icon above a short caption. Prominent segments carry the accent.
struct FloatingActionLabel: View {
    let title: String
    let systemImage: String
    var isProminent = false
    var role: ButtonRole?

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .medium))
                .frame(height: 22)
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .frame(minWidth: 64)
        .padding(.horizontal, 8)
        .frame(height: 54)
        .background {
            if isProminent {
                Capsule().fill(ScanTheme.primaryFill)
            }
        }
        .contentShape(Capsule())
    }

    private var foreground: Color {
        if isProminent { return ScanTheme.onAccent }
        if role == .destructive { return .red }
        return ScanTheme.ink
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

/// The four corner brackets from the app icon.
struct ViewfinderCorners: Shape {
    var length: CGFloat = 0.24

    func path(in rect: CGRect) -> Path {
        let arm = min(rect.width, rect.height) * length
        let radius = arm * 0.45
        var path = Path()

        func corner(_ origin: CGPoint, _ dx: CGFloat, _ dy: CGFloat) {
            path.move(to: CGPoint(x: origin.x, y: origin.y + dy * arm))
            path.addLine(to: CGPoint(x: origin.x, y: origin.y + dy * radius))
            path.addQuadCurve(
                to: CGPoint(x: origin.x + dx * radius, y: origin.y),
                control: origin
            )
            path.addLine(to: CGPoint(x: origin.x + dx * arm, y: origin.y))
        }

        corner(CGPoint(x: rect.minX, y: rect.minY), 1, 1)
        corner(CGPoint(x: rect.maxX, y: rect.minY), -1, 1)
        corner(CGPoint(x: rect.minX, y: rect.maxY), 1, -1)
        corner(CGPoint(x: rect.maxX, y: rect.maxY), -1, -1)
        return path
    }
}

/// A faint measuring grid, fading toward the edges.
struct GridBackdrop: View {
    var spacing: CGFloat = 46

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x = (size.width.truncatingRemainder(dividingBy: spacing)) / 2
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y = (size.height.truncatingRemainder(dividingBy: spacing)) / 2
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(ScanTheme.border.opacity(0.55)), lineWidth: 0.5)
        }
        .mask {
            RadialGradient(
                colors: [.black, .black.opacity(0.4), .clear],
                center: .center,
                startRadius: 40,
                endRadius: 420
            )
        }
        .accessibilityHidden(true)
    }
}

extension ScanQualityState {
    var tint: Color {
        switch self {
        case .analyzing: ScanTheme.secondaryInk
        case .ready where needsReview: ScanTheme.warning
        case .ready where needsVisualReview: ScanTheme.secondaryInk
        case .ready: ScanTheme.accent
        }
    }
}

extension Int {
    var pageCountText: String {
        "\(self) \(self == 1 ? "page" : "pages")"
    }
}
