import SwiftUI
import UIKit

struct CropPageView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onComplete: (UIImage) -> Void

    @State private var cropMode = CropMode.fourCorners
    @State private var quadrilateral = CropQuadrilateral.fullImage
    @State private var uniformRect = CGRect(x: 0, y: 0, width: 1, height: 1)
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

                    switch cropMode {
                    case .fourCorners:
                        PerspectiveCropOverlay(quadrilateral: $quadrilateral, imageRect: imageRect)
                    case .uniform:
                        UniformCropOverlay(cropRect: $uniformRect, imageRect: imageRect)
                    }

                    if isApplying {
                        Color.black.opacity(0.45).ignoresSafeArea()
                        ProgressView("Applying Crop…")
                            .tint(.white)
                            .foregroundStyle(.white)
                            .padding(20)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .navigationTitle("Crop Page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isApplying)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Reset") {
                        withAnimation(.snappy) {
                            resetCurrentCrop()
                        }
                    }
                    .disabled(isApplying || isCurrentCropFullImage)
                }
            }
            .safeAreaInset(edge: .bottom) {
                applyBar
            }
        }
        .interactiveDismissDisabled(isApplying)
        .onChange(of: cropMode) { oldMode, newMode in
            convertCrop(from: oldMode, to: newMode)
            UISelectionFeedbackGenerator().selectionChanged()
        }
        .alert("Unable to Crop Page", isPresented: Binding(
            get: { cropError != nil },
            set: { if !$0 { cropError = nil } }
        )) {
            Button("OK", role: .cancel) { cropError = nil }
        } message: {
            Text(cropError ?? "Please adjust the crop area and try again.")
        }
    }

    private var applyBar: some View {
        VStack(spacing: 10) {
            Picker("Crop Mode", selection: $cropMode) {
                ForEach(CropMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isApplying)

            Text(cropMode.instruction)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(action: applyCrop) {
                Label("Apply Crop", systemImage: "crop")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isApplying)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private func applyCrop() {
        isApplying = true
        let selectedMode = cropMode
        let selectedQuadrilateral = quadrilateral
        let selectedUniformRect = uniformRect

        Task {
            do {
                let croppedImage = try await Task.detached(priority: .userInitiated) {
                    switch selectedMode {
                    case .fourCorners:
                        try DocumentCropper.crop(image, to: selectedQuadrilateral)
                    case .uniform:
                        try DocumentCropper.crop(image, to: selectedUniformRect)
                    }
                }.value
                onComplete(croppedImage)
            } catch {
                cropError = error.localizedDescription
                isApplying = false
            }
        }
    }

    private var isCurrentCropFullImage: Bool {
        switch cropMode {
        case .fourCorners:
            quadrilateral == .fullImage
        case .uniform:
            uniformRect == CGRect(x: 0, y: 0, width: 1, height: 1)
        }
    }

    private func resetCurrentCrop() {
        switch cropMode {
        case .fourCorners:
            quadrilateral = .fullImage
        case .uniform:
            uniformRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
    }

    private func convertCrop(from oldMode: CropMode, to newMode: CropMode) {
        guard oldMode != newMode else { return }

        switch newMode {
        case .fourCorners:
            quadrilateral = CropQuadrilateral(
                topLeft: CGPoint(x: uniformRect.minX, y: uniformRect.minY),
                topRight: CGPoint(x: uniformRect.maxX, y: uniformRect.minY),
                bottomRight: CGPoint(x: uniformRect.maxX, y: uniformRect.maxY),
                bottomLeft: CGPoint(x: uniformRect.minX, y: uniformRect.maxY)
            )
        case .uniform:
            let xValues = [
                quadrilateral.topLeft.x,
                quadrilateral.topRight.x,
                quadrilateral.bottomRight.x,
                quadrilateral.bottomLeft.x
            ]
            let yValues = [
                quadrilateral.topLeft.y,
                quadrilateral.topRight.y,
                quadrilateral.bottomRight.y,
                quadrilateral.bottomLeft.y
            ]
            guard let minX = xValues.min(), let maxX = xValues.max(),
                  let minY = yValues.min(), let maxY = yValues.max() else { return }
            uniformRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
    }

    private func aspectFitRect(for imageSize: CGSize, in availableSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let handleMargin: CGFloat = 18
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
}

private enum CropMode: String, CaseIterable, Identifiable {
    case fourCorners
    case uniform

    var id: Self { self }

    var title: String {
        switch self {
        case .fourCorners: "4 Corners"
        case .uniform: "Rectangle"
        }
    }

    var instruction: String {
        switch self {
        case .fourCorners: "Drag each corner to correct the document perspective"
        case .uniform: "Resize or drag the rectangle for a standard crop"
        }
    }
}

private struct PerspectiveCropOverlay: View {
    @Binding var quadrilateral: CropQuadrilateral
    let imageRect: CGRect

    var body: some View {
        ZStack {
            outsideMask
            cropOutline
            handle(for: .topLeft)
            handle(for: .topRight)
            handle(for: .bottomRight)
            handle(for: .bottomLeft)
        }
    }

    private var outsideMask: some View {
        Canvas { context, size in
            var path = Path(CGRect(origin: .zero, size: size))
            path.move(to: viewPoint(for: quadrilateral.topLeft))
            path.addLine(to: viewPoint(for: quadrilateral.topRight))
            path.addLine(to: viewPoint(for: quadrilateral.bottomRight))
            path.addLine(to: viewPoint(for: quadrilateral.bottomLeft))
            path.closeSubpath()
            context.fill(
                path,
                with: .color(.black.opacity(0.55)),
                style: FillStyle(eoFill: true)
            )
        }
        .allowsHitTesting(false)
    }

    private var cropOutline: some View {
        Path { path in
            path.move(to: viewPoint(for: quadrilateral.topLeft))
            path.addLine(to: viewPoint(for: quadrilateral.topRight))
            path.addLine(to: viewPoint(for: quadrilateral.bottomRight))
            path.addLine(to: viewPoint(for: quadrilateral.bottomLeft))
            path.closeSubpath()
        }
        .stroke(.blue, style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        .allowsHitTesting(false)
    }

    private func handle(for corner: CropCorner) -> some View {
        Circle()
            .fill(.white)
            .frame(width: 30, height: 30)
            .overlay {
                Circle().stroke(.blue, lineWidth: 5)
            }
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
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

private struct UniformCropOverlay: View {
    @Binding var cropRect: CGRect
    let imageRect: CGRect

    @State private var dragStartRect: CGRect?

    var body: some View {
        ZStack {
            outsideMask
            moveArea
            ruleOfThirdsGrid
            cropOutline

            ForEach(UniformCropHandle.allCases) { handle in
                resizeHandle(handle)
            }
        }
    }

    private var outsideMask: some View {
        Canvas { context, size in
            var path = Path(CGRect(origin: .zero, size: size))
            path.addRect(viewCropRect)
            context.fill(
                path,
                with: .color(.black.opacity(0.55)),
                style: FillStyle(eoFill: true)
            )
        }
        .allowsHitTesting(false)
    }

    private var moveArea: some View {
        Rectangle()
            .fill(Color.white.opacity(0.001))
            .frame(width: viewCropRect.width, height: viewCropRect.height)
            .position(x: viewCropRect.midX, y: viewCropRect.midY)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStartRect == nil {
                            dragStartRect = cropRect
                        }
                        guard let startRect = dragStartRect,
                              imageRect.width > 0,
                              imageRect.height > 0 else { return }

                        let proposedX = startRect.minX + value.translation.width / imageRect.width
                        let proposedY = startRect.minY + value.translation.height / imageRect.height
                        cropRect.origin = CGPoint(
                            x: min(max(proposedX, 0), 1 - startRect.width),
                            y: min(max(proposedY, 0), 1 - startRect.height)
                        )
                    }
                    .onEnded { _ in
                        dragStartRect = nil
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            )
            .accessibilityLabel("Crop selection")
            .accessibilityHint("Drag to move the crop rectangle")
    }

    private var cropOutline: some View {
        Path(viewCropRect)
            .stroke(.blue, style: StrokeStyle(lineWidth: 3, lineJoin: .round))
            .allowsHitTesting(false)
    }

    private var ruleOfThirdsGrid: some View {
        Path { path in
            for fraction in [CGFloat(1) / 3, CGFloat(2) / 3] {
                let x = viewCropRect.minX + viewCropRect.width * fraction
                path.move(to: CGPoint(x: x, y: viewCropRect.minY))
                path.addLine(to: CGPoint(x: x, y: viewCropRect.maxY))

                let y = viewCropRect.minY + viewCropRect.height * fraction
                path.move(to: CGPoint(x: viewCropRect.minX, y: y))
                path.addLine(to: CGPoint(x: viewCropRect.maxX, y: y))
            }
        }
        .stroke(.white.opacity(0.55), lineWidth: 1)
        .allowsHitTesting(false)
    }

    private func resizeHandle(_ handle: UniformCropHandle) -> some View {
        Circle()
            .fill(.white)
            .frame(width: handle.isCorner ? 28 : 24, height: handle.isCorner ? 28 : 24)
            .overlay {
                Circle().stroke(.blue, lineWidth: 4)
            }
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            .position(viewPoint(for: normalizedPoint(for: handle)))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        resize(handle, to: normalizedPoint(for: value.location))
                    }
                    .onEnded { _ in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            )
            .accessibilityLabel(handle.accessibilityLabel)
            .accessibilityHint("Drag to resize the crop rectangle")
    }

    private var viewCropRect: CGRect {
        CGRect(
            x: imageRect.minX + cropRect.minX * imageRect.width,
            y: imageRect.minY + cropRect.minY * imageRect.height,
            width: cropRect.width * imageRect.width,
            height: cropRect.height * imageRect.height
        )
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

    private func normalizedPoint(for handle: UniformCropHandle) -> CGPoint {
        switch handle {
        case .topLeft: CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .top: CGPoint(x: cropRect.midX, y: cropRect.minY)
        case .topRight: CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .right: CGPoint(x: cropRect.maxX, y: cropRect.midY)
        case .bottomRight: CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        case .bottom: CGPoint(x: cropRect.midX, y: cropRect.maxY)
        case .bottomLeft: CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .left: CGPoint(x: cropRect.minX, y: cropRect.midY)
        }
    }

    private func resize(_ handle: UniformCropHandle, to point: CGPoint) {
        let minimumSpan: CGFloat = 0.05
        var minX = cropRect.minX
        var minY = cropRect.minY
        var maxX = cropRect.maxX
        var maxY = cropRect.maxY

        switch handle {
        case .topLeft:
            minX = min(point.x, maxX - minimumSpan)
            minY = min(point.y, maxY - minimumSpan)
        case .top:
            minY = min(point.y, maxY - minimumSpan)
        case .topRight:
            maxX = max(point.x, minX + minimumSpan)
            minY = min(point.y, maxY - minimumSpan)
        case .right:
            maxX = max(point.x, minX + minimumSpan)
        case .bottomRight:
            maxX = max(point.x, minX + minimumSpan)
            maxY = max(point.y, minY + minimumSpan)
        case .bottom:
            maxY = max(point.y, minY + minimumSpan)
        case .bottomLeft:
            minX = min(point.x, maxX - minimumSpan)
            maxY = max(point.y, minY + minimumSpan)
        case .left:
            minX = min(point.x, maxX - minimumSpan)
        }

        cropRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
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

private enum UniformCropHandle: CaseIterable, Identifiable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    var id: Self { self }

    var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomRight, .bottomLeft: true
        case .top, .right, .bottom, .left: false
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .topLeft: "Top-left crop handle"
        case .top: "Top crop edge"
        case .topRight: "Top-right crop handle"
        case .right: "Right crop edge"
        case .bottomRight: "Bottom-right crop handle"
        case .bottom: "Bottom crop edge"
        case .bottomLeft: "Bottom-left crop handle"
        case .left: "Left crop edge"
        }
    }
}
