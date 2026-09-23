import Foundation
import Photos

/// Add-only Photos authorization state. Add-only access never reports `.limited`; the
/// conformer maps it to `.authorized` and any unknown future case to `.denied`
/// (S3 spec review, point 3).
enum PhotoAddAuth: Equatable, Sendable { case notDetermined, authorized, denied, restricted }

protocol PhotoLibrarySaving: Sendable {
    func addOnlyStatus() async -> PhotoAddAuth
    func requestAddOnly() async -> PhotoAddAuth
    func saveVideo(at url: URL) async throws    // PHAssetCreationRequest, .video resource
}

/// PhotoKit implementation (S3 spec §3). Decision 5: add-only only — the app never reads
/// the photo library. No CI test: compile-only there, verified on device at S5.
struct PHPhotoLibrarySaver: PhotoLibrarySaving {
    init() {}

    func addOnlyStatus() async -> PhotoAddAuth {
        Self.map(PHPhotoLibrary.authorizationStatus(for: .addOnly))
    }

    func requestAddOnly() async -> PhotoAddAuth {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return Self.map(status)
    }

    func saveVideo(at url: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .video, fileURL: url, options: nil)
        }
    }

    private static func map(_ status: PHAuthorizationStatus) -> PhotoAddAuth {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized, .limited: return .authorized
        @unknown default: return .denied
        }
    }
}
