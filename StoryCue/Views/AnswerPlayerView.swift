@preconcurrency import AVFoundation
import AVKit
import SwiftUI

/// The answer the full-screen player is playing, identified by its question. `id` is the
/// question ID, so a `fullScreenCover(item:)` presents exactly one player per answer.
struct PlayableAnswer: Identifiable, Hashable {
    let questionID: String
    var id: String { questionID }
}

/// The system player: `AVPlayerViewController` with its own transport controls — no custom
/// chrome. Only wraps an existing player; it never creates or owns one.
struct SystemPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

/// Full-screen playback of one answer. Sources are the segment files export would use;
/// `AVStitcher.makeComposition` builds the composition in memory — playback never writes a
/// file and never touches the segment directory. States: loading (`ProgressView`), playing
/// (autoplayed once ready) and unavailable (`UICopy.playbackUnavailable`, when the build
/// throws or nothing is readable). The question text sits in a dark material card at the
/// top, over the video and above the system controls' hit area; after 3 seconds it shrinks
/// to one line (instantly under Reduce Motion) and never fully disappears.
struct AnswerPlayerView: View {
    let sources: [URL]
    let caption: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var player: AVPlayer?
    @State private var isReady = false
    @State private var isUnavailable = false
    @State private var captionExpanded = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player {
                SystemPlayer(player: player)
                    .ignoresSafeArea()
            }
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    captionCard
                    Spacer(minLength: 0)
                    Button(UICopy.done) { dismiss() }
                        .font(.body)
                        .frame(minWidth: 44, minHeight: 44)
                        .background(.black.opacity(0.5), in: Capsule())
                }
                .padding()
                Spacer()
            }
            if isUnavailable {
                Text(UICopy.playbackUnavailable)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding()
            } else if !isReady {
                ProgressView()
            }
        }
        // `.task`, not `onAppear` + `Task {}`: SwiftUI cancels these when the cover is
        // dismissed, so a load that finishes after dismissal never starts an invisible player.
        .task { await load() }
        .task { await shrinkCaption() }
        .onDisappear(perform: release)
    }

    private var captionCard: some View {
        Text(caption)
            .font(.body)
            .lineLimit(captionExpanded ? nil : 1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .environment(\.colorScheme, .dark)
    }

    private func load() async {
        // Playback owns the audio session while the cover is up. Nothing restores it:
        // AVCaptureSession.automaticallyConfiguresApplicationAudioSession reconfigures the
        // app audio session itself when the next recording starts (see the comment near
        // AVCaptureService.swift:160 — unverified, so it is on the S2c device-check list).
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .moviePlayback)
        try? audioSession.setActive(true)

        do {
            let built = try await AVStitcher.makeComposition(sources)
            guard !Task.isCancelled else { return }
            guard built.durationSeconds > 0 else {
                isUnavailable = true
                return
            }
            let readyPlayer = AVPlayer(playerItem: AVPlayerItem(asset: built.composition))
            player = readyPlayer
            isReady = true
            readyPlayer.play()
        } catch is CancellationError {
            // The cover was dismissed mid-load: nothing to show, and not "unavailable".
        } catch {
            guard !Task.isCancelled else { return }
            isUnavailable = true
        }
    }

    private func shrinkCaption() async {
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : .default) {
            captionExpanded = false
        }
    }

    private func release() {
        player?.pause()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
