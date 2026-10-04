import SwiftUI
import UIKit

/// Every way to bring pages in, in one menu. Paste only appears when there is something to paste.
struct AddPagesMenu<MenuLabel: View>: View {
    var includesScan = true
    let onScan: () -> Void
    let onImportPhotos: () -> Void
    let onImportPDF: () -> Void
    let onPaste: () -> Void
    @ViewBuilder let label: () -> MenuLabel

    @Environment(\.scenePhase) private var scenePhase
    @State private var canPaste = false

    var body: some View {
        Menu {
            if includesScan {
                Button(action: onScan) {
                    Label("Scan Documents", systemImage: "doc.viewfinder")
                }
            }

            Button(action: onImportPhotos) {
                Label("Choose Photos", systemImage: "photo.on.rectangle")
            }

            Button(action: onImportPDF) {
                Label("Choose PDF", systemImage: "folder")
            }

            if canPaste {
                Button(action: onPaste) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
            }
        } label: {
            label()
        }
        .onAppear(perform: refreshPasteboard)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshPasteboard()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            refreshPasteboard()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.removedNotification)) { _ in
            refreshPasteboard()
        }
    }

    private func refreshPasteboard() {
        canPaste = PasteboardImageImporter.supportedContentLabel(in: .general) != nil
    }
}
