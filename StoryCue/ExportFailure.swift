import AVFoundation
import Foundation
import Photos

/// The only error type an export ever surfaces (S3 spec §5). The Exporter wraps every
/// throw with `from(_:)`, so callers only ever see this enum.
enum ExportFailure: Error, Equatable, Sendable {
    case nothingToExport
    case insufficientSpace(neededBytes: Int64, availableBytes: Int64)
    case outOfSpace                      // disk filled during the write
    case photosDenied, photosRestricted
    indirect case partiallySavedToPhotos(saved: Int, total: Int, cause: ExportFailure)
    case cancelled
    case failed(domain: String, code: Int)

    /// Maps any error thrown by AVFoundation / PhotoKit / Foundation / cancellation.
    /// Checks apply in the order listed in the spec's table.
    static func from(_ error: any Error) -> ExportFailure {
        if let failure = error as? ExportFailure { return failure }

        let nsError = error as NSError

        if error is CancellationError
            || (nsError.domain == NSCocoaErrorDomain
                && nsError.code == CocoaError.Code.userCancelled.rawValue) {
            return .cancelled
        }
        if (nsError.domain == AVFoundationErrorDomain
                && nsError.code == AVError.diskFull.rawValue)
            || (nsError.domain == NSCocoaErrorDomain
                && nsError.code == CocoaError.Code.fileWriteOutOfSpace.rawValue)
            || (error as? POSIXError)?.code == .ENOSPC {
            return .outOfSpace
        }
        if nsError.domain == PHPhotosErrorDomain {
            let code = PHPhotosError.Code(rawValue: nsError.code)
            if code == .accessUserDenied { return .photosDenied }
            if code == .accessRestricted { return .photosRestricted }
        }
        return .failed(domain: nsError.domain, code: nsError.code)
    }

    /// User-visible copy. Plain, no blame, no jargon; lives here, not in UICopy (S2a).
    /// Every message that follows a failed write says the recordings are safe — true by
    /// construction, because nothing in the export engine writes to or deletes from the
    /// segment directory.
    var userMessage: String {
        switch self {
        case .nothingToExport:
            return "There's nothing to export yet. None of these clips have any saved video."
        case let .insufficientSpace(neededBytes, availableBytes):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let shortfall = formatter.string(fromByteCount: max(neededBytes - availableBytes, 0))
            return "Your iPhone needs about \(shortfall) more free space to export this. Free up some space and try again."
        case .outOfSpace:
            return "Your iPhone ran out of space during the export. Your recordings are safe. Free up some space and try again."
        case .photosDenied:
            return "StoryCue can't save to Photos. To allow it, go to Settings › StoryCue › Photos and choose Add Photos Only."
        case .photosRestricted:
            return "Saving to Photos is restricted on this iPhone. Export to Files instead."
        case let .partiallySavedToPhotos(saved, total, cause):
            return "\(saved) of \(total) clips were saved to Photos before the export stopped. \(cause.userMessage)"
        case .cancelled:
            return "Export canceled. Your recordings are unchanged."
        case .failed:
            return "The export didn't finish. Your recordings are safe. Try again."
        }
    }
}
