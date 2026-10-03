import SwiftUI
import UIKit

/// Full-screen page viewer with pinch and double-tap zoom, for checking fine print before export.
struct PageZoomView: View {
    let image: UIImage
    let title: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZoomableImageView(image: image)
                .ignoresSafeArea(edges: .bottom)
                .background(Color.black)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.black, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

private struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 6
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .black

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.accessibilityLabel = "Page image"
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
        DispatchQueue.main.async {
            context.coordinator.layout(in: scrollView)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        private var lastBoundsSize: CGSize = .zero

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func layout(in scrollView: UIScrollView) {
            guard let imageView, scrollView.bounds.size != lastBoundsSize else { return }
            lastBoundsSize = scrollView.bounds.size
            scrollView.zoomScale = 1
            imageView.frame = CGRect(origin: .zero, size: scrollView.bounds.size)
            scrollView.contentSize = scrollView.bounds.size
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView = recognizer.view as? UIScrollView, let imageView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let point = recognizer.location(in: imageView)
                let zoomScale = min(scrollView.maximumZoomScale, 3)
                let size = CGSize(
                    width: scrollView.bounds.width / zoomScale,
                    height: scrollView.bounds.height / zoomScale
                )
                scrollView.zoom(
                    to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height),
                    animated: true
                )
            }
        }
    }
}
