import SwiftUI
import VisionKit

/// Reviews one page at a time. Swipe sideways to move between pages; the
/// editing actions sit in a bottom bar so they stay within thumb reach.
struct PageDetailView: View {
    @ObservedObject var session: ScanSession

    @Environment(\.dismiss) private var dismiss
    @State private var currentPageID: UUID
    @State private var isDeleteConfirmationPresented = false
    @State private var isRescanPresented = false
    @State private var cropRequest: CropRequest?
    @State private var zoomRequest: ZoomRequest?
    @State private var alertMessage: String?

    init(session: ScanSession, initialPageID: UUID) {
        self.session = session
        _currentPageID = State(initialValue: initialPageID)
    }

    private var currentPage: ScannedPage? {
        session.page(withID: currentPageID)
    }

    private var currentPageNumber: Int {
        session.pageNumber(for: currentPageID) ?? 1
    }

    var body: some View {
        Group {
            if currentPage != nil {
                TabView(selection: $currentPageID) {
                    ForEach(Array(session.pages.enumerated()), id: \.element.id) { index, page in
                        PageReviewContent(
                            session: session,
                            page: page,
                            onZoom: { zoomRequest = ZoomRequest(image: page.image, pageNumber: index + 1) }
                        )
                        .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .safeAreaInset(edge: .bottom) { editBar }
            } else {
                ContentUnavailableView("Page Removed", systemImage: "doc.badge.minus")
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(session.pages.count > 1
            ? "Page \(currentPageNumber) of \(session.pages.count)"
            : "Page \(currentPageNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: currentPageID) { _, _ in
            Haptics.selection()
        }
        .confirmationDialog(
            "Delete Page \(currentPageNumber)?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Page", role: .destructive, action: deleteCurrentPage)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This page and its recognized text will be removed from the scan.")
        }
        .fullScreenCover(item: $cropRequest) { request in
            CropPageView(
                image: request.image,
                onCancel: { cropRequest = nil },
                onComplete: { croppedImage in
                    session.applyCrop(pageID: request.pageID, image: croppedImage)
                    cropRequest = nil
                }
            )
        }
        .fullScreenCover(item: $zoomRequest) { request in
            PageZoomView(image: request.image, title: "Page \(request.pageNumber)")
        }
        .fullScreenCover(isPresented: $isRescanPresented) {
            DocumentScannerView(
                onComplete: { images in
                    session.replace(pageID: currentPageID, with: images)
                    isRescanPresented = false
                },
                onCancel: { isRescanPresented = false },
                onError: { error in
                    isRescanPresented = false
                    alertMessage = error.localizedDescription
                }
            )
            .ignoresSafeArea()
        }
        .alert("Unable to Rescan Page", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "Please try again.")
        }
    }

    private var editBar: some View {
        BottomActionBar {
            HStack(spacing: 0) {
                editButton("Rescan", systemImage: "camera.viewfinder", action: beginRescan)
                editButton("Crop", systemImage: "crop") {
                    if let currentPage {
                        cropRequest = CropRequest(pageID: currentPage.id, image: currentPage.image)
                    }
                }
                editButton("Rotate", systemImage: "rotate.right") {
                    session.rotate(pageID: currentPageID)
                    Haptics.impact()
                }
                editButton("Delete", systemImage: "trash", role: .destructive) {
                    isDeleteConfirmationPresented = true
                }
            }
        }
    }

    private func editButton(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(height: 24)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(role == .destructive ? Color.red : Color.accentColor)
    }

    private func beginRescan() {
        guard VNDocumentCameraViewController.isSupported else {
            alertMessage = "Document scanning requires a supported iPhone camera."
            return
        }
        isRescanPresented = true
    }

    private func deleteCurrentPage() {
        guard let index = session.pages.firstIndex(where: { $0.id == currentPageID }) else { return }
        let deletedPageID = currentPageID
        let remaining = session.pages.filter { $0.id != deletedPageID }

        guard !remaining.isEmpty else {
            session.remove(pageID: deletedPageID)
            dismiss()
            return
        }

        withAnimation(.snappy) {
            currentPageID = remaining[min(index, remaining.count - 1)].id
        }
        session.remove(pageID: deletedPageID)
    }
}

private struct PageReviewContent: View {
    @ObservedObject var session: ScanSession
    let page: ScannedPage
    let onZoom: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                pagePreview

                QualitySummaryCard(quality: page.quality)

                recognizedTextCard
            }
            .padding(16)
        }
    }

    private var pagePreview: some View {
        Button(action: onZoom) {
            Image(uiImage: page.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .pageSurface(cornerRadius: 14)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.45), in: Circle())
                        .padding(10)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Page image")
        .accessibilityHint("Opens the page full screen so you can zoom in")
    }

    private var recognizedTextCard: some View {
        NavigationLink {
            RecognizedTextView(session: session, pageID: page.id)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "text.viewfinder")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Recognized Text")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(textSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .cardSurface()
        }
        .buttonStyle(.plain)
        .disabled(page.quality == .analyzing)
    }

    private var textSummary: String {
        if page.quality == .analyzing { return "Recognizing text on device…" }
        if page.recognizedText.isEmpty { return "No readable text was found." }
        return page.recognizedText.replacingOccurrences(of: "\n", with: " ")
    }
}

private struct CropRequest: Identifiable {
    let id = UUID()
    let pageID: UUID
    let image: UIImage
}

private struct ZoomRequest: Identifiable {
    let id = UUID()
    let image: UIImage
    let pageNumber: Int
}
