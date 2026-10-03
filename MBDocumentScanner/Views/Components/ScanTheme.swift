import SwiftUI
import UIKit

/// A quiet canvas and one expressive accent, shared by every screen.
enum ScanTheme {
    static let accent = adaptive(light: 0x087F72, dark: 0x78D6C2)
    static let accentSoft = adaptive(light: 0xE3F2ED, dark: 0x203A34)
    static let background = adaptive(light: 0xF5F7F4, dark: 0x111A17)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x1B2722)
    static let ink = adaptive(light: 0x1B302A, dark: 0xEEF5F0)
    static let secondaryInk = adaptive(light: 0x606F68, dark: 0xABBDB2)
    static let border = adaptive(light: 0xE3EAE4, dark: 0x33453B)
    static let primaryFill = Color(red: 8 / 255, green: 127 / 255, blue: 114 / 255)

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
    func scanCard(cornerRadius: CGFloat = 24) -> some View {
        background(ScanTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(ScanTheme.border.opacity(0.7), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

struct ScanPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 17)
            .frame(minHeight: 54)
            .background(ScanTheme.primaryFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

struct ScanSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(ScanTheme.accent)
            .padding(.horizontal, 18)
            .padding(.vertical, 17)
            .frame(minHeight: 54)
            .background(ScanTheme.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

struct ScanSectionHeading: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(ScanTheme.ink)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(ScanTheme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
