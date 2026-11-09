@preconcurrency import AVFoundation
import AVKit
import Combine
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
/// (autoplayed once the player item reports ready) and unavailable (`UICopy.playbackUnavailable`
/// when the build throws, nothing is readable or the item fails; `UICopy.playbackAudioBusy` when
/// the audio session can't be taken). The cover is always dark, whatever the system appearance.
/// The question text sits in a dark material card at the top, over the video and above the
/// system controls' hit area; after 3 seconds it shrinks to one line (instantly under Reduce
/// Motion, never at accessibility text sizes) and a tap on it toggles the whole question back.
struct AnswerPlayerView: View {
    let sources: [URL]
    let caption: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var player: AVPlayer?
    @State private var isReady = false
    @State private var unavailableMessage: String?
    @State private var captionExpanded = true
    @State private var captionToggledByUser = false

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
            if let unavailableMessage {
                Text(unavailableMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if !isReady {
                ProgressView()
            }
        }
        // The backdrop is always black, so the text, spinner and Done must use dark-appearance
        // colors even when the phone is in light mode (light `.secondary` is gray on black).
        .environment(\.colorScheme, .dark)
        // `.task`, not `onAppear` + `Task {}`: SwiftUI cancels these when the cover is
        // dismissed, so a load that finishes after dismissal never starts an invisible player.
        .task { await load() }
        .task { await shrinkCaption() }
        .onDisappear(perform: release)
    }

    private var captionCard: some View {
        Button {
            captionToggledByUser = true
            withAnimation(reduceMotion ? nil : DesignTokens.Motion.fade) {
                captionExpanded.toggle()
            }
        } label: {
            Text(caption)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(captionExpanded ? nil : 1)
                .padding(.horizontal, DesignTokens.Spacing.m)
                .padding(.vertical, DesignTokens.Spacing.s)
                .frame(minHeight: 44)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(caption)
        .accessibilityHint(captionExpanded ? UICopy.captionCollapseHint : UICopy.captionExpandHint)
        .accessibilityIdentifier("playerCaption")
    }

    private func load() async {
        // Playback owns the audio session while the cover is up. Nothing restores it:
        // AVCaptureSession.automaticallyConfiguresApplicationAudioSession reconfigures the
        // app audio session itself when the next recording starts (see the comment near
        // AVCaptureService.swift:160 — unverified, so it is on the S2c device-check list).
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true)
        } catch {
            // A player with no sound and no message would look broken; say why instead.
            unavailableMessage = UICopy.playbackAudioBusy
            return
        }

        do {
            let built = try await AVStitcher.makeComposition(sources)
            guard !Task.isCancelled else { return }
            guard built.durationSeconds > 0 else {
                unavailableMessage = UICopy.playbackUnavailable
                return
            }
            let item = AVPlayerItem(asset: built.composition)
            let readyPlayer = AVPlayer(playerItem: item)
            player = readyPlayer
            // Keep the spinner until the item itself is ready; an item that fails to load
            // shows "unavailable" instead of a silent, empty player.
            for await status in item.publisher(for: \.status).values {
                guard !Task.isCancelled else { return }
                switch status {
                case .readyToPlay:
                    isReady = true
                    readyPlayer.play()
                    return
                case .failed:
                    unavailableMessage = UICopy.playbackUnavailable
                    return
                case .unknown:
                    continue
                @unknown default:
                    continue
                }
            }
        } catch is CancellationError {
            // The cover was dismissed mid-load: nothing to show, and not "unavailable".
        } catch {
            guard !Task.isCancelled else { return }
            unavailableMessage = UICopy.playbackUnavailable
        }
    }

    private func shrinkCaption() async {
        try? await Task.sleep(for: .seconds(3))
        // At accessibility sizes one line hides most of the question; a tap the user already
        // made wins over the timer.
        guard !Task.isCancelled, !captionToggledByUser, !dynamicTypeSize.isAccessibilitySize else { return }
        withAnimation(reduceMotion ? nil : DesignTokens.Motion.fade) {
            captionExpanded = false
        }
    }

    private func release() {
        player?.pause()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
