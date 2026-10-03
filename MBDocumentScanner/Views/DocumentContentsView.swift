import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

struct DocumentContentsView: View {
    @ObservedObject var library: ScanLibrary
    @ObservedObject var session: ScanSession

    @Environment(\.dismiss) private var dismiss
    @State private var isScannerPresented = false
    @State private var isPDFImporterPresented = false
    @State private var isExportPresented = false
    @State private var isRenamePresented = false
    @State private var isDeletePresented = false
    @State private var draftTitle = ""
    @State private var alertMessage: String?
    @State private var draggedPageID: UUID?
    @State private var pendingPageDeletion: PendingPageDeletion?

    private let gridColumns = [
        GridItem(.adaptive(minimum: 148, maximum: 220), spacing: 16)
    ]

    var body: some View {
        Group {
            if session.isEmpty {
                ContentUnavailableView {
                    Label("No Pages", systemImage: "doc.viewfinder")
                } description: {
                    Text("Scan or import pages to add them to this document.")
                } actions: {
                    Button("Scan Pages", action: beginScanning)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                pagesGrid
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleMenu {
            Button(action: beginRename) {
                Label("Rename", systemImage: "pencil")
            }
        }
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) { actionBar }
        .fullScreenCover(isPresented: $isScannerPresented) {
            DocumentScannerView(
                onComplete: { images in
                    session.add(images)
                    isScannerPresented = false
                },
                onCancel: { isScannerPresented = false },
                onError: { error in
                    isScannerPresented = false
                    alertMessage = error.localizedDescription
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isExportPresented) {
            ExportOptionsView(session: session)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .pdfPageImporter(
            isPresented: $isPDFImporterPresented,
            onImport: { images, _ in
                session.add(images)
            },
            onError: { error in
                alertMessage = error.localizedDescription
            }
        )
        .alert("Rename Scan", isPresented: $isRenamePresented) {
            TextField("Name", text: $draftTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") { session.rename(to: draftTitle) }
        }
        .alert("Unable to Add Pages", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "Please try again.")
        }
        .confirmationDialog(
            "Delete Page \(pendingPageDeletion?.pageNumber ?? 1)?",
            isPresented: Binding(
                get: { pendingPageDeletion != nil },
                set: { if !$0 { pendingPageDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Page", role: .destructive) {
                if let pendingPageDeletion {
                    withAnimation(.snappy) {
                        session.remove(pageID: pendingPageDeletion.pageID)
                    }
                }
                pendingPageDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                pendingPageDeletion = nil
            }
        } message: {
            Text("This page and its recognized text will be removed from the scan.")
        }
        .confirmationDialog(
            "Delete \(session.title)?",
            isPresented: $isDeletePresented,
            titleVisibility: .visible
        ) {
            Button("Delete Scan", role: .destructive) {
                library.delete(documentID: session.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its pages and recognized text will be removed from this device.")
        }
    }

    private var pagesGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryHeader

                LazyVGrid(columns: gridColumns, spacing: 20) {
                    ForEach(Array(session.pages.enumerated()), id: \.element.id) { index, page in
                        pageCell(page, index: index)
                    }
                }

                Label("Touch and hold a page to reorder, rotate, or delete it.", systemImage: "hand.tap")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        // Catches drops that land between cards so a finished drag never leaves stale state.
        .onDrop(of: [UTType.plainText], isTargeted: nil) { _ in
            draggedPageID = nil
            return false
        }
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(pageCountText(session.pages.count)) · Edited \(session.modifiedAt.formatted(.relative(presentation: .named)))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if session.pagesNeedingReview > 0 {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(session.pagesNeedingReview) \(session.pagesNeedingReview == 1 ? "page needs" : "pages need") review")
                            .font(.subheadline.weight(.semibold))
                        Text("Open a marked page to see what to fix, then rescan, crop, or rotate it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func pageCell(_ page: ScannedPage, index: Int) -> some View {
        NavigationLink {
            PageDetailView(session: session, initialPageID: page.id)
        } label: {
            PageCard(page: page, pageNumber: index + 1)
        }
        .buttonStyle(.plain)
        .contextMenu { pageActions(for: page, index: index) }
        .onDrag {
            draggedPageID = page.id
            Haptics.impact()
            return NSItemProvider(object: page.id.uuidString as NSString)
        }
        .onDrop(
            of: [UTType.plainText],
            delegate: PageReorderDropDelegate(
                targetPageID: page.id,
                session: session,
                draggedPageID: $draggedPageID
            )
        )
    }

    @ViewBuilder
    private func pageActions(for page: ScannedPage, index: Int) -> some View {
        Button {
            session.rotate(pageID: page.id)
        } label: {
            Label("Rotate", systemImage: "rotate.right")
        }

        if index > 0 {
            Button {
                movePage(page.id, toIndex: index - 1)
            } label: {
                Label("Move Earlier", systemImage: "arrow.left")
            }
        }

        if index < session.pages.count - 1 {
            Button {
                movePage(page.id, toIndex: index + 1)
            } label: {
                Label("Move Later", systemImage: "arrow.right")
            }
        }

        Divider()

        Button(role: .destructive) {
            pendingPageDeletion = PendingPageDeletion(pageID: page.id, pageNumber: index + 1)
        } label: {
            Label("Delete Page", systemImage: "trash")
        }
    }

    private var actionBar: some View {
        BottomActionBar {
            HStack(spacing: 12) {
                Button(action: beginScanning) {
                    Label("Scan", systemImage: "doc.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Scan More Pages")

                ImportMenu(
                    onImportPDF: { isPDFImporterPresented = true },
                    onPaste: pastePages
                )
                .buttonStyle(.bordered)

                Button {
                    isExportPresented = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.isEmpty)
            }
            .controlSize(.large)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(action: beginRename) {
                    Label("Rename", systemImage: "pencil")
                }

                Button {
                    isExportPresented = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(session.isEmpty)

                Divider()

                Button(role: .destructive) {
                    isDeletePresented = true
                } label: {
                    Label("Delete Scan", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Scan options")
        }
    }

    private func beginRename() {
        draftTitle = session.title
        isRenamePresented = true
    }

    private func movePage(_ pageID: UUID, toIndex targetIndex: Int) {
        guard session.pages.indices.contains(targetIndex) else { return }
        withAnimation(.snappy) {
            _ = session.movePage(pageID, toPositionOf: session.pages[targetIndex].id)
        }
        Haptics.selection()
    }

    private func beginScanning() {
        guard VNDocumentCameraViewController.isSupported else {
            alertMessage = "Document scanning requires a supported iPhone camera."
            return
        }
        isScannerPresented = true
    }

    private func pastePages() {
        do {
            session.add(try PasteboardImageImporter.importImages())
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}

private struct PendingPageDeletion {
    let pageID: UUID
    let pageNumber: Int
}

private struct PageReorderDropDelegate: DropDelegate {
    let targetPageID: UUID
    let session: ScanSession
    @Binding var draggedPageID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggedPageID else { return }

        var didMove = false
        withAnimation(.snappy(duration: 0.18)) {
            didMove = session.movePage(draggedPageID, toPositionOf: targetPageID)
        }

        if didMove {
            Haptics.selection()
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedPageID = nil
        Haptics.impact(.medium)
        return true
    }
}
