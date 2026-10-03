import SwiftUI
import UIKit

/// A bottom-anchored bar for a screen's primary actions, shared so every
/// screen places its main buttons in the same thumb-reachable spot.
struct BottomActionBar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 8) {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

enum PageSurface {
    static let cornerRadius: CGFloat = 12
}

extension View {
    /// Presents a page image as a sheet of paper: white backing, hairline edge, and soft shadow.
    func pageSurface(cornerRadius: CGFloat = PageSurface.cornerRadius) -> some View {
        background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    /// Groups content on the standard inset card background.
    func cardSurface() -> some View {
        background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

func pageCountText(_ count: Int) -> String {
    count == 1 ? "1 page" : "\(count) pages"
}

extension ScanQualityState {
    var tintColor: Color {
        switch self {
        case .analyzing: .secondary
        case .ready where needsReview: .orange
        case .ready: .green
        }
    }
}

enum Haptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
