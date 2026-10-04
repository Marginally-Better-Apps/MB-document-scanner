import SwiftUI
import VisionKit

/// One page, large. Swipe for the next page; tools sit in the bottom toolbar.
struct PageDetailView: View {
    @ObservedObject var session: ScanSession

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPageID: UUID
    @State private var isDeleteConfirmationPresented = false
    @State private var cropRequest: CropRequest?
    @State private var editRequest: EditRequest?
    @State private var isZoomPresented = false
    @State private var isTextPresented = false
    @State private var isRetakePresented = false
    @State private var alertMessage: String?
    @State private var rotationCount = 0

    init(session: ScanSession, pageID: UUID) {
        self.session = session
        _selectedPageID = State(initialValue: pageID)
    }

    private var pageNumber: Int { session.pageNumber(for: selectedPageID) ?? 1 }

    var body: some View {
        Group {
            if let page = session.page(withID: selectedPageID) {
                VStack(spacing: 0) {
                    pager

                    if !page.quality.activeWarnings.isEmpty {
                        PageWarningBanner(
                            headline: page.quality.activeWarnings[0].plainHeadline,
                            onRetake: beginRetake,
                            onKeep: { keepPage(page) }
                        )
                        .frame(maxWidth: 560)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.snappy, value: page.quality.activeWarnings.count)
                .fullScreenCover(isPresented: $isZoomPresented) {
                    PageZoomView(image: page.image, title: "Page \(pageNumber)")
                }
                .toolbar { toolbarContent(page) }
            } else {
                ContentUnavailableView("Page Removed", systemImage: "doc.badge.minus")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ScanTheme.background)
        .navigationTitle("Page \(pageNumber) of \(session.pages.count)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isTextPresented) {
            RecognizedTextView(session: session, pageID: selectedPageID)
        }
        .sensoryFeedback(.selection, trigger: rotationCount)
        .alert(
            "Delete Page \(pageNumber)?",
            isPresented: $isDeleteConfirmationPresented
        ) {
            Button("Delete Page", role: .destructive, action: deleteSelectedPage)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This page will be removed from the scan.")
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "Please try again.")
        }
        .fullScreenCover(isPresented: $isRetakePresented) {
            DocumentScannerView(
                onComplete: { images in
                    if let image = images.first {
                        session.applyEdit(pageID: selectedPageID, image: image)
                    }
                    isRetakePresented = false
                },
                onCancel: { isRetakePresented = false },
                onError: { error in
                    isRetakePresented = false
                    alertMessage = error.localizedDescription
                }
            )
            .ignoresSafeArea()
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
        .fullScreenCover(item: $editRequest) { request in
            PageEditorView(
                image: request.image,
                pageNumber: request.pageNumber,
                onCancel: { editRequest = nil },
                onComplete: { editedImage in
                    session.applyEdit(pageID: request.pageID, image: editedImage)
                    editRequest = nil
                }
            )
        }
    }

    private var pager: some View {
        TabView(selection: $selectedPageID) {
            ForEach(Array(session.pages.enumerated()), id: \.element.id) { index, page in
                Button {
                    isZoomPresented = true
                } label: {
                    PaperImage(image: page.image, cornerRadius: 6)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Page \(index + 1)")
                .accessibilityHint("Double-tap to zoom. Swipe left or right with three fingers for other pages.")
                .tag(page.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    @ToolbarContentBuilder
    private func toolbarContent(_ page: ScannedPage) -> some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                editRequest = EditRequest(pageID: page.id, image: page.image, pageNumber: pageNumber)
            } label: {
                Label("Markup", systemImage: "pencil.tip.crop.circle")
            }

            Button {
                cropRequest = CropRequest(pageID: page.id, image: page.image)
            } label: {
                Label("Crop", systemImage: "crop")
            }

            Button {
                rotationCount += 1
                session.rotate(pageID: page.id)
            } label: {
                Label("Rotate", systemImage: "rotate.right")
            }

            Button {
                isTextPresented = true
            } label: {
                Label("Text", systemImage: "text.viewfinder")
            }
            .disabled(page.quality == .analyzing)
            .accessibilityLabel("Show Text")

            Spacer()

            Button(role: .destructive) {
                isDeleteConfirmationPresented = true
            } label: {
                Label("Delete Page", systemImage: "trash")
            }
        }
    }

    private func beginRetake() {
        guard VNDocumentCameraViewController.isSupported else {
            alertMessage = "Retaking a page needs a device with a camera."
            return
        }
        isRetakePresented = true
    }

    private func keepPage(_ page: ScannedPage) {
        withAnimation(.snappy) {
            for check in page.quality.activeWarnings {
                session.setWarningDismissed(true, checkID: check.id, pageID: page.id)
            }
        }
    }

    private func deleteSelectedPage() {
        let pages = session.pages
        guard let index = pages.firstIndex(where: { $0.id == selectedPageID }) else { return }
        let deletedID = selectedPageID
        if pages.count == 1 {
            session.remove(pageID: deletedID)
            dismiss()
            return
        }
        selectedPageID = index + 1 < pages.count ? pages[index + 1].id : pages[index - 1].id
        withAnimation { session.remove(pageID: deletedID) }
    }
}

/// A plain-language note when a page might not read well, with the two things you can do about it.
private struct PageWarningBanner: View {
    let headline: String
    let onRetake: () -> Void
    let onKeep: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ScanTheme.warning)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(.headline)
                        .foregroundStyle(ScanTheme.ink)
                    Text("Retake it, or keep it if you can read it.")
                        .font(.subheadline)
                        .foregroundStyle(ScanTheme.secondaryInk)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10))
                : AnyLayout(HStackLayout(spacing: 10))

            layout {
                Button(action: onRetake) {
                    Text("Retake")
                        .frame(maxWidth: .infinity)
                }
                Button(action: onKeep) {
                    Text("It’s Fine")
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.body.weight(.semibold))
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(16)
        .scanCard(cornerRadius: 22)
        .accessibilityElement(children: .contain)
    }
}

private struct CropRequest: Identifiable {
    let id = UUID()
    let pageID: UUID
    let image: UIImage
}

private struct EditRequest: Identifiable {
    let id = UUID()
    let pageID: UUID
    let image: UIImage
    let pageNumber: Int
}
