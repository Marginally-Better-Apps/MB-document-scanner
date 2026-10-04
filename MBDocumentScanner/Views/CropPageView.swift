import SwiftUI
import UIKit

/// Drag the four corners onto the page's edges. The page is straightened when you tap Done.
struct CropPageView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onComplete: (UIImage) -> Void

    @State private var quadrilateral = CropQuadrilateral.fullImage
    @State private var isApplying = false
    @State private var cropError: String?

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let imageRect = aspectFitRect(for: image.size, in: geometry.size)

                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageRect.width, height: imageRect.height)
                        .position(x: imageRect.midX, y: imageRect.midY)

                    CropExclusionOverlay(
                        image: image,
                        imageRect: imageRect,
                        cropPath: cropPath(in: imageRect)
                    )

                    PerspectiveCropOverlay(
                        quadrilateral: $quadrilateral,
                        imageRect: imageRect
                    )

                    if isApplying {
                        Color.black.opacity(0.45).ignoresSafeArea()
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                    }
                }
            }
            .navigationTitle("Crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isApplying)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: applyCrop)
                        .fontWeight(.semibold)
                        .disabled(isApplying)
                }

                ToolbarItem(placement: .bottomBar) {
                    Button("Reset") {
                        withAnimation(.snappy) {
                            quadrilateral = .fullImage
                        }
                    }
                    .disabled(isApplying || quadrilateral == .fullImage)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Text("Drag the corners to the edges of the page.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isApplying)
        .alert("Unable to Crop Page", isPresented: Binding(
            get: { cropError != nil },
            set: { if !$0 { cropError = nil } }
        )) {
            Button("OK", role: .cancel) { cropError = nil }
        } message: {
            Text(cropError ?? "Please adjust the corners and try again.")
        }
    }

    private func applyCrop() {
        isApplying = true
        let selectedQuadrilateral = quadrilateral

        Task {
            do {
                let croppedImage = try await Task.detached(priority: .userInitiated) {
                    try DocumentCropper.crop(image, to: selectedQuadrilateral)
                }.value
                onComplete(croppedImage)
            } catch {
                cropError = error.localizedDescription
                isApplying = false
            }
        }
    }

    private func aspectFitRect(for imageSize: CGSize, in availableSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let handleMargin: CGFloat = 26
        let usableSize = CGSize(
            width: max(1, availableSize.width - handleMargin * 2),
            height: max(1, availableSize.height - handleMargin * 2)
        )
        let scale = min(
            usableSize.width / imageSize.width,
            usableSize.height / imageSize.height
        )
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (availableSize.width - fittedSize.width) / 2,
            y: (availableSize.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    private func cropPath(in imageRect: CGRect) -> Path {
        Path { path in
            path.move(to: viewPoint(for: quadrilateral.topLeft, in: imageRect))
            path.addLine(to: viewPoint(for: quadrilateral.topRight, in: imageRect))
            path.addLine(to: viewPoint(for: quadrilateral.bottomRight, in: imageRect))
            path.addLine(to: viewPoint(for: quadrilateral.bottomLeft, in: imageRect))
            path.closeSubpath()
        }
    }

    private func viewPoint(for normalizedPoint: CGPoint, in imageRect: CGRect) -> CGPoint {
        CGPoint(
            x: imageRect.minX + normalizedPoint.x * imageRect.width,
            y: imageRect.minY + normalizedPoint.y * imageRect.height
        )
    }
}

private struct PerspectiveCropOverlay: View {
    @Binding var quadrilateral: CropQuadrilateral
    let imageRect: CGRect

    var body: some View {
        ZStack {
            cropOutline
            handle(for: .topLeft)
            handle(for: .topRight)
            handle(for: .bottomRight)
            handle(for: .bottomLeft)
        }
    }

    private var cropOutline: some View {
        cropPath
            .stroke(.white, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            .shadow(color: .black.opacity(0.4), radius: 1)
            .allowsHitTesting(false)
    }

    private var cropPath: Path {
        Path { path in
            path.move(to: viewPoint(for: quadrilateral.topLeft))
            path.addLine(to: viewPoint(for: quadrilateral.topRight))
            path.addLine(to: viewPoint(for: quadrilateral.bottomRight))
            path.addLine(to: viewPoint(for: quadrilateral.bottomLeft))
            path.closeSubpath()
        }
    }

    private func handle(for corner: CropCorner) -> some View {
        Circle()
            .fill(.white)
            .frame(width: 22, height: 22)
            .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
            .frame(width: 48, height: 48)
            .contentShape(Circle())
            .position(viewPoint(for: point(for: corner)))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        move(corner, to: normalizedPoint(for: value.location))
                    }
            )
            .accessibilityLabel(corner.accessibilityLabel)
            .accessibilityHint("Drag to adjust this crop corner")
    }

    private func viewPoint(for normalizedPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: imageRect.minX + normalizedPoint.x * imageRect.width,
            y: imageRect.minY + normalizedPoint.y * imageRect.height
        )
    }

    private func normalizedPoint(for viewPoint: CGPoint) -> CGPoint {
        guard imageRect.width > 0, imageRect.height > 0 else { return .zero }
        return CGPoint(
            x: min(max((viewPoint.x - imageRect.minX) / imageRect.width, 0), 1),
            y: min(max((viewPoint.y - imageRect.minY) / imageRect.height, 0), 1)
        )
    }

    private func point(for corner: CropCorner) -> CGPoint {
        switch corner {
        case .topLeft: quadrilateral.topLeft
        case .topRight: quadrilateral.topRight
        case .bottomRight: quadrilateral.bottomRight
        case .bottomLeft: quadrilateral.bottomLeft
        }
    }

    private func move(_ corner: CropCorner, to point: CGPoint) {
        let minimumSpan = 0.05

        switch corner {
        case .topLeft:
            quadrilateral.topLeft = CGPoint(
                x: min(point.x, min(quadrilateral.topRight.x, quadrilateral.bottomRight.x) - minimumSpan),
                y: min(point.y, min(quadrilateral.bottomLeft.y, quadrilateral.bottomRight.y) - minimumSpan)
            )
        case .topRight:
            quadrilateral.topRight = CGPoint(
                x: max(point.x, max(quadrilateral.topLeft.x, quadrilateral.bottomLeft.x) + minimumSpan),
                y: min(point.y, min(quadrilateral.bottomRight.y, quadrilateral.bottomLeft.y) - minimumSpan)
            )
        case .bottomRight:
            quadrilateral.bottomRight = CGPoint(
                x: max(point.x, max(quadrilateral.topLeft.x, quadrilateral.bottomLeft.x) + minimumSpan),
                y: max(point.y, max(quadrilateral.topLeft.y, quadrilateral.topRight.y) + minimumSpan)
            )
        case .bottomLeft:
            quadrilateral.bottomLeft = CGPoint(
                x: min(point.x, min(quadrilateral.topRight.x, quadrilateral.bottomRight.x) - minimumSpan),
                y: max(point.y, max(quadrilateral.topLeft.y, quadrilateral.topRight.y) + minimumSpan)
            )
        }
    }
}


private struct CropExclusionOverlay: View {
    let image: UIImage
    let imageRect: CGRect
    let cropPath: Path

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: imageRect.width, height: imageRect.height)
                .position(x: imageRect.midX, y: imageRect.midY)
                .saturation(0)
                .contrast(0.8)
                .brightness(-0.18)
                .mask(exclusionMask)

            Color.black.opacity(0.28)
                .mask(exclusionMask)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var exclusionMask: some View {
        Canvas { context, _ in
            context.fill(Path(imageRect), with: .color(.white))
            context.blendMode = .destinationOut
            context.fill(cropPath, with: .color(.white))
        }
    }
}

private enum CropCorner {
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft

    var accessibilityLabel: String {
        switch self {
        case .topLeft: "Top-left crop corner"
        case .topRight: "Top-right crop corner"
        case .bottomRight: "Bottom-right crop corner"
        case .bottomLeft: "Bottom-left crop corner"
        }
    }
}
