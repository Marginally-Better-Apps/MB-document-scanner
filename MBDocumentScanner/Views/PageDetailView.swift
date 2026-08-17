import SwiftUI

struct PageDetailView: View {
    @ObservedObject var session: ScanSession
    let pageID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var isDeleteConfirmationPresented = false
    @State private var cropRequest: CropRequest?

    var body: some View {
        Group {
            if let page = session.page(withID: pageID) {
                ScrollView {
                    VStack(spacing: 20) {
                        pagePreview(page)

                        QualitySummaryCard(quality: page.quality)

                        recognizedTextCard(page)
                    }
                    .padding(16)
                    .padding(.bottom, 20)
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("Page \(session.pageNumber(for: pageID) ?? 1)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            cropRequest = CropRequest(image: page.image)
                        } label: {
                            Image(systemName: "crop")
                        }
                        .accessibilityLabel("Crop page")

                        Button {
                            session.rotate(pageID: pageID)
                        } label: {
                            Image(systemName: "rotate.right")
                        }
                        .accessibilityLabel("Rotate page")

                        Menu {
                            Button(role: .destructive) {
                                isDeleteConfirmationPresented = true
                            } label: {
                                Label("Delete Page", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Page options")
                    }
                }
            } else {
                ContentUnavailableView("Page Removed", systemImage: "doc.badge.minus")
            }
        }
        .confirmationDialog(
            "Delete this page?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Page", role: .destructive) {
                session.remove(pageID: pageID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This only removes the page from the current scan.")
        }
        .fullScreenCover(item: $cropRequest) { request in
            CropPageView(
                image: request.image,
                onCancel: { cropRequest = nil },
                onComplete: { croppedImage in
                    session.applyCrop(pageID: pageID, image: croppedImage)
                    cropRequest = nil
                }
            )
        }
    }

    private func pagePreview(_ page: ScannedPage) -> some View {
        Image(uiImage: page.image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
    }

    private func recognizedTextCard(_ page: ScannedPage) -> some View {
        NavigationLink {
            RecognizedTextView(session: session, pageID: pageID)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "text.viewfinder")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Recognized Text")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(textSummary(for: page))
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
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(page.quality == .analyzing)
    }

    private func textSummary(for page: ScannedPage) -> String {
        if page.quality == .analyzing { return "Recognizing text on device…" }
        if page.recognizedText.isEmpty { return "No readable text was found." }
        return page.recognizedText.replacingOccurrences(of: "\n", with: " ")
    }
}

private struct CropRequest: Identifiable {
    let id = UUID()
    let image: UIImage
}
