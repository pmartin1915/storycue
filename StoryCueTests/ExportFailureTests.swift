import AVFoundation
import Foundation
import Photos
import XCTest
@testable import StoryCue

/// ExportFailure mapping and userMessage tests (S3 spec §6).
final class ExportFailureTests: XCTestCase {
    func testMapsCancellation() {
        XCTAssertEqual(ExportFailure.from(CancellationError()), .cancelled)
        XCTAssertEqual(ExportFailure.from(CocoaError(.userCancelled)), .cancelled)
    }

    func testMapsDiskFullVariants() {
        XCTAssertEqual(ExportFailure.from(AVError(.diskFull)), .outOfSpace)
        XCTAssertEqual(ExportFailure.from(CocoaError(.fileWriteOutOfSpace)), .outOfSpace)
        XCTAssertEqual(ExportFailure.from(POSIXError(.ENOSPC)), .outOfSpace)
    }

    func testMapsPhotosErrors() {
        XCTAssertEqual(ExportFailure.from(PHPhotosError(.accessUserDenied)), .photosDenied)
        XCTAssertEqual(ExportFailure.from(PHPhotosError(.accessRestricted)), .photosRestricted)
    }

    func testPassesThroughExportFailure() {
        XCTAssertEqual(ExportFailure.from(ExportFailure.outOfSpace), .outOfSpace)
        XCTAssertEqual(
            ExportFailure.from(ExportFailure.partiallySavedToPhotos(saved: 1, total: 3, cause: .photosDenied)),
            .partiallySavedToPhotos(saved: 1, total: 3, cause: .photosDenied)
        )
    }

    func testUnknownErrorKeepsDomainAndCode() {
        let error = NSError(domain: "com.storycue.test", code: 42)
        XCTAssertEqual(ExportFailure.from(error), .failed(domain: "com.storycue.test", code: 42))
    }

    func testEveryPostWriteMessageSaysRecordingsAreSafe() {
        for failure in [ExportFailure.outOfSpace, .cancelled, .failed(domain: "x", code: 1)] {
            XCTAssertTrue(
                failure.userMessage.contains("recordings"),
                "\(failure) message must mention the recordings: \(failure.userMessage)"
            )
        }
    }

    func testInsufficientSpaceMessageFormatsShortfall() {
        let failure = ExportFailure.insufficientSpace(neededBytes: 2_000_000_000, availableBytes: 1_000_000_000)
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let expectedShortfall = formatter.string(fromByteCount: 1_000_000_000)
        XCTAssertEqual(
            failure.userMessage,
            "Your iPhone needs about \(expectedShortfall) more free space to export this. Free up some space and try again."
        )
    }

    func testPartiallySavedMessageCountsAndIncludesCause() {
        let failure = ExportFailure.partiallySavedToPhotos(saved: 1, total: 3, cause: .photosDenied)
        XCTAssertEqual(
            failure.userMessage,
            "1 of 3 clips were saved to Photos before the export stopped. \(ExportFailure.photosDenied.userMessage)"
        )
    }
}
