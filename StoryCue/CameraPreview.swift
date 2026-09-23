// Spec §1 pre-registered fix: `AVCaptureSession` carries no NS_SWIFT_SENDABLE
// annotation in current SDKs (Apple's own AVCam sample ships the same import), so the
// plain import makes `SessionPreviewSource: Sendable` fail to compile. This file holds
// only the preview types, keeping the relaxation scoped (spec §1 note).
@preconcurrency import AVFoundation
import SwiftUI
import UIKit

// Preview layer (Apple's AVCam pattern). The capture service owns ONE
// `AVCaptureSession` object for its whole life and hands the UI a Sendable source that
// can connect a preview view to it — so the view never touches the session directly.

protocol PreviewSource: Sendable {
    @MainActor func connect(to target: any PreviewTarget)
}

@MainActor
protocol PreviewTarget: AnyObject {
    func setSession(_ session: AVCaptureSession)
}

/// The real source: holds the capture service's permanent session object.
struct SessionPreviewSource: PreviewSource {
    let session: AVCaptureSession
    @MainActor func connect(to target: any PreviewTarget) { target.setSession(session) }
}

/// Mock / simulator: connects nothing; the view shows its black placeholder.
struct NoPreviewSource: PreviewSource {
    @MainActor func connect(to target: any PreviewTarget) {}
}

final class PreviewUIView: UIView, PreviewTarget {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("layerClass")
        }
        return layer
    }

    func setSession(_ session: AVCaptureSession) {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }
}

struct CameraPreview: UIViewRepresentable {
    let source: any PreviewSource

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        source.connect(to: view)
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}
