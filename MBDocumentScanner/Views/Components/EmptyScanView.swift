import SwiftUI

/// The first thing a new person sees: what this is, and one button to start.
struct EmptyScanView: View {
    let onScan: () -> Void
    let onImportPhotos: () -> Void
    let onImportPDF: () -> Void
    let onPaste: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Scans", systemImage: "doc.viewfinder")
        } description: {
            Text("Scan paper documents with your camera.")
        } actions: {
            Button(action: onScan) {
                Text("Scan Document")
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .prominentActionStyle()
            .controlSize(.large)

            AddPagesMenu(
                includesScan: false,
                onScan: onScan,
                onImportPhotos: onImportPhotos,
                onImportPDF: onImportPDF,
                onPaste: onPaste
            ) {
                Text("Add from Photos or Files")
            }
        }
    }
}
