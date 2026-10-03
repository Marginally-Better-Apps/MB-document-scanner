import Combine
import SwiftUI
import UIKit

/// The secondary ways to add pages. Scanning stays a separate one-tap button
/// so the most common action never hides behind a menu.
struct ImportMenu: View {
    let onImportPDF: () -> Void
    let onPaste: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var pasteboardLabel: String?
    @State private var lastPasteboardChangeCount = -1

    private let refreshTimer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    var body: some View {
        Menu {
            Button(action: onImportPDF) {
                Label("Import PDF", systemImage: "doc.badge.plus")
            }

            Button(action: onPaste) {
                Label(pasteButtonTitle, systemImage: "doc.on.clipboard")
            }
            .disabled(pasteboardLabel == nil)
        } label: {
            Image(systemName: "square.and.arrow.down")
                .font(.headline)
                .frame(minWidth: 28)
        }
        .accessibilityLabel("Import")
        .accessibilityHint("Import a PDF or paste an image")
        .onAppear { refreshPasteboard(force: true) }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshPasteboard(force: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            refreshPasteboard(force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.removedNotification)) { _ in
            refreshPasteboard(force: true)
        }
        .onReceive(refreshTimer) { _ in
            guard scenePhase == .active else { return }
            refreshPasteboard()
        }
    }

    private var pasteButtonTitle: String {
        pasteboardLabel.map { "Paste \($0)" } ?? "Paste Image"
    }

    private func refreshPasteboard(force: Bool = false) {
        let pasteboard = UIPasteboard.general
        guard force || pasteboard.changeCount != lastPasteboardChangeCount else { return }
        lastPasteboardChangeCount = pasteboard.changeCount
        pasteboardLabel = PasteboardImageImporter.supportedContentLabel(in: pasteboard)
    }
}
