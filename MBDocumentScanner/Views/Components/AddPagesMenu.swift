import Combine
import SwiftUI
import UIKit

struct AddPagesMenu<MenuLabel: View>: View {
    var includesScan = true
    let onScan: () -> Void
    let onImportPhotos: () -> Void
    let onImportPDF: () -> Void
    let onPaste: () -> Void
    @ViewBuilder let label: () -> MenuLabel

    @Environment(\.scenePhase) private var scenePhase
    @State private var pasteboardLabel: String?
    @State private var lastPasteboardChangeCount = -1

    private let refreshTimer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    var body: some View {
        Menu {
            if includesScan {
                Section {
                    Button(action: onScan) {
                        Label("Scan Document", systemImage: "doc.viewfinder")
                    }
                }
            }

            Section {
                Button(action: onImportPhotos) {
                    Label("Photos", systemImage: "photo.on.rectangle")
                }

                Button(action: onImportPDF) {
                    Label("PDF from Files", systemImage: "folder")
                }

                Button(action: onPaste) {
                    Label(pasteButtonTitle, systemImage: "doc.on.clipboard")
                }
                .disabled(pasteboardLabel == nil)
            }
        } label: {
            label()
        }
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
        pasteboardLabel.map { "Paste (\($0))" } ?? "Paste Image"
    }

    private func refreshPasteboard(force: Bool = false) {
        let pasteboard = UIPasteboard.general
        guard force || pasteboard.changeCount != lastPasteboardChangeCount else { return }
        lastPasteboardChangeCount = pasteboard.changeCount
        pasteboardLabel = PasteboardImageImporter.supportedContentLabel(in: pasteboard)
    }
}
