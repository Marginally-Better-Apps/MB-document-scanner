import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import MBDocumentScanner

final class PhotoLibraryImageImporterTests: XCTestCase {
    func testEmptySelectionDoesNotLoadPhotos() async throws {
        let images = try await PhotoLibraryImageImporter.importImages(from: [Int]()) { _ in
            XCTFail("An empty selection must not load photos.")
            return nil
        }

        XCTAssertTrue(images.isEmpty)
    }

    func testPreservesSelectionOrderAcrossSuspendedLoads() async throws {
        let firstLoadStarted = expectation(description: "First photo load started")
        let loader = SuspendedPhotoLoader(
            data: [
                1: try makePNG(width: 20, height: 40),
                2: try makePNG(width: 60, height: 30)
            ],
            firstLoadStarted: firstLoadStarted
        )
        let task = Task {
            try await PhotoLibraryImageImporter.importImages(from: [2, 1]) { item in
                await loader.load(item)
            }
        }

        await fulfillment(of: [firstLoadStarted], timeout: 2)
        let requestsWhileSuspended = await loader.requests
        XCTAssertEqual(requestsWhileSuspended, [2])
        await loader.resumeFirstLoad()

        let images = try await task.value
        XCTAssertEqual(images.map(\.size), [
            CGSize(width: 60, height: 30),
            CGSize(width: 20, height: 40)
        ])
        let requests = await loader.requests
        XCTAssertEqual(requests, [2, 1])
    }

    func testFailedPhotoRejectsSelectionAndStopsBeforeLaterPhotos() async throws {
        let validData = try makePNG(width: 20, height: 40)
        let failures: [(Data?, Bool, PhotoLibraryImageImportError)] = [
            (nil, false, .unavailablePhoto(2)),
            (nil, true, .unavailablePhoto(2)),
            (Data("invalid image".utf8), false, .unsupportedPhoto(2))
        ]

        for (failingData, throwsError, expectedError) in failures {
            let recorder = PhotoLoadRecorder()
            do {
                _ = try await PhotoLibraryImageImporter.importImages(from: [10, 20, 30]) { item in
                    await recorder.record(item)
                    if item == 20 {
                        if throwsError { throw LoaderFailure.failed }
                        return failingData
                    }
                    return validData
                }
                XCTFail("A failed photo must reject the selection without returning partial images.")
            } catch {
                XCTAssertEqual(error as? PhotoLibraryImageImportError, expectedError)
            }
            let requests = await recorder.requests
            XCTAssertEqual(requests, [10, 20])
        }
    }

    func testCancellationDuringLoadDoesNotRequestMorePhotos() async throws {
        let firstLoadStarted = expectation(description: "First photo load started")
        let loader = SuspendedPhotoLoader(
            data: [1: try makePNG(width: 20, height: 40)],
            firstLoadStarted: firstLoadStarted
        )
        let task = Task {
            try await PhotoLibraryImageImporter.importImages(from: [1, 2]) { item in
                await loader.load(item)
            }
        }

        await fulfillment(of: [firstLoadStarted], timeout: 2)
        task.cancel()
        await loader.resumeFirstLoad()

        do {
            _ = try await task.value
            XCTFail("A canceled import must not return images.")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        let requests = await loader.requests
        XCTAssertEqual(requests, [1])
    }

    func testJPEGOrientationMetadataIsPreserved() async throws {
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ))
        let cgImage = try XCTUnwrap(makeImage(width: 20, height: 40).cgImage)
        CGImageDestinationAddImage(destination, cgImage, [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        let images = try await PhotoLibraryImageImporter.importImages(from: [data as Data]) { $0 }
        let image = try XCTUnwrap(images.first)

        XCTAssertEqual(image.imageOrientation, .right)
        XCTAssertEqual(try XCTUnwrap(image.cgImage).width, 20)
        XCTAssertEqual(try XCTUnwrap(image.cgImage).height, 40)
    }

    private func makePNG(width: CGFloat, height: CGFloat) throws -> Data {
        try XCTUnwrap(makeImage(width: width, height: height).pngData())
    }

    private func makeImage(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: width, height: height)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

private enum LoaderFailure: Error {
    case failed
}

private actor PhotoLoadRecorder {
    private(set) var requests: [Int] = []

    func record(_ item: Int) {
        requests.append(item)
    }
}

private actor SuspendedPhotoLoader {
    let data: [Int: Data]
    let firstLoadStarted: XCTestExpectation
    private(set) var requests: [Int] = []
    private var firstLoad: CheckedContinuation<Data?, Never>?

    init(data: [Int: Data], firstLoadStarted: XCTestExpectation) {
        self.data = data
        self.firstLoadStarted = firstLoadStarted
    }

    func load(_ item: Int) async -> Data? {
        requests.append(item)
        if requests.count == 1 {
            return await withCheckedContinuation { continuation in
                firstLoad = continuation
                firstLoadStarted.fulfill()
            }
        }
        return data[item]
    }

    func resumeFirstLoad() {
        firstLoad?.resume(returning: requests.first.flatMap { data[$0] })
        firstLoad = nil
    }
}
