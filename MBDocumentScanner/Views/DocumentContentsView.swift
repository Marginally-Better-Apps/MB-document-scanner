import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

struct DocumentContentsView: View {
    @ObservedObject var library: ScanLibrary
    @ObservedObject var session: ScanSession
    @EnvironmentObject private var settings: AppSettings

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isScannerPresented = false
    @State private var isPhotoImporterPresented = false
    @State private var isPDFImporterPresented = false
    @State private var isExportPresented = false
    @State private var isRenamePresented = false
    @State private var isDeletePresented = false
    @State private var draftTitle = ""
    @State private var alertMessage: String?
    @State private var draggedPageID: UUID?
    @State private var pendingPageDeletion: PendingPageDeletion?

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 260 : 148, maximum: 320), spacing: 16)]
    }

    var body: some View {
        Group {
            if session.isEmpty {
                ContentUnavailableView(
                    "No Pages",
                    systemImage: "doc.viewfinder",
                    description: Text("Add pages to this scan or delete it from the options menu.")
                )
            } else {
                pagesGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ScanTheme.background)
        .tint(ScanTheme.accent)
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
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
            ExportOptionsView(
                session: session,
                format: settings.exportFormat,
                compression: settings.compression
            )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .photoLibraryImporter(
            isPresented: $isPhotoImporterPresented,
            onImport: { images in
                session.add(images)
            },
            onError: { error in
                alertMessage = error.localizedDescription
            }
        )
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
        .alert(
            "Delete Page \(pendingPageDeletion?.pageNumber ?? 1)?",
            isPresented: Binding(
                get: { pendingPageDeletion != nil },
                set: { if !$0 { pendingPageDeletion = nil } }
            )
        ) {
            Button("Delete Page", role: .destructive) {
                if let pendingPageDeletion {
                    session.remove(pageID: pendingPageDeletion.pageID)
                }
                pendingPageDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                pendingPageDeletion = nil
            }
        } message: {
            Text("This page and its recognized text will be removed from the scan.")
        }
        .alert(
            "Delete \(session.title)?",
            isPresented: $isDeletePresented
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
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 16) {
                    ScanSectionHeading(
                        title: "Pages",
                        detail: session.pages.count > 1 ? "Tap to review. Hold and drag to reorder." : "Tap to review or edit your page."
                    )

                    Spacer(minLength: 0)

                    Text("\(session.pages.count)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(ScanTheme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(ScanTheme.accentSoft, in: Capsule())
                        .accessibilityLabel("\(session.pages.count) \(session.pages.count == 1 ? "page" : "pages")")
                }

                LazyVGrid(columns: gridColumns, spacing: 18) {
                    ForEach(Array(session.pages.enumerated()), id: \.element.id) { index, page in
                        ZStack(alignment: .topTrailing) {
                            NavigationLink {
                                PageDetailView(session: session, pageID: page.id)
                            } label: {
                                PageCard(page: page, pageNumber: index + 1)
                            }
                            .buttonStyle(.plain)

                            Button {
                                pendingPageDeletion = PendingPageDeletion(
                                    pageID: page.id,
                                    pageNumber: index + 1
                                )
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(ScanTheme.secondaryInk)
                                    .frame(width: 28, height: 28)
                                    .background(ScanTheme.surface.opacity(0.96), in: Circle())
                                    .overlay {
                                        Circle().stroke(ScanTheme.border, lineWidth: 1)
                                    }
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete Page \(index + 1)")
                            .padding(6)
                        }
                        .opacity(draggedPageID == page.id ? 0.65 : 1)
                        .onDrag {
                            draggedPageID = page.id
                            let feedback = UIImpactFeedbackGenerator(style: .light)
                            feedback.prepare()
                            feedback.impactOccurred()
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
                }
            }
            .padding(20)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    private var actionBar: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    addPagesButton
                    exportButton
                }
            } else {
                HStack(spacing: 12) {
                    addPagesButton
                    exportButton
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(ScanTheme.background)
        .overlay(alignment: .top) {
            Rectangle().fill(ScanTheme.border).frame(height: 1)
        }
    }

    private var addPagesButton: some View {
        AddPagesMenu(
            onScan: beginScanning,
            onImportPhotos: { isPhotoImporterPresented = true },
            onImportPDF: { isPDFImporterPresented = true },
            onPaste: pastePages
        ) {
            Label("Add pages", systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ScanSecondaryButtonStyle())
    }

    private var exportButton: some View {
        Button {
            isExportPresented = true
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ScanPrimaryButtonStyle())
        .disabled(session.isEmpty)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    draftTitle = session.title
                    isRenamePresented = true
                } label: {
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

    private func beginScanning() {
        guard VNDocumentCameraViewController.isSupported else {
            alertMessage = "Document scanning requires a supported device camera."
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
            let feedback = UISelectionFeedbackGenerator()
            feedback.prepare()
            feedback.selectionChanged()
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedPageID = nil
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.prepare()
        feedback.impactOccurred()
        return true
    }
}
