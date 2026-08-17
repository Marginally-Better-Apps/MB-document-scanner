import UIKit

struct ScannedPage: Identifiable {
    let id: UUID
    var image: UIImage
    var recognizedText: String
    var quality: ScanQualityState

    init(
        id: UUID = UUID(),
        image: UIImage,
        recognizedText: String = "",
        quality: ScanQualityState = .analyzing
    ) {
        self.id = id
        self.image = image
        self.recognizedText = recognizedText
        self.quality = quality
    }
}

