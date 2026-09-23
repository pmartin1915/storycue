import SwiftUI
import UIKit

struct RecorderView: View {
    let session: AppModel.ActiveSession
    let model: AppModel

    @Environment(\.scenePhase) private var scenePhase
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?

    private var store: SessionStore { session.store }

    private var presentation: RecorderPresentation {
        RecorderPresentation.make(
            state: store.state,
            availability: store.captureAvailability,
            hasAudioInput: store.hasAudioInput,
            elapsed: store.elapsedInSegment,
            countdown: countdown
        )
    }

    var body: some View {
        ZStack {
            CameraPreview(source: session.capture.previewSource)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                questionPanel
                Spacer(minLength: 0)
                timerRow
                bannerRow
                controlsRow
                    .padding(.bottom, 24)
            }
            .padding(.horizontal)

            if presentation.blocking != .none {
                blockingOverlay
            }

            if let countdownText = presentation.countdownText {
                countdownOverlay(countdownText)
            }
        }
        .task { store.startTicker() }
        .onDisappear { cancelCountdown() }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(UICopy.done) {
                    Task { await model.endSession() }
                }
                .disabled(!presentation.canLeave)
                .accessibilityLabel(UICopy.done)
            }
        }
        .onChange(of: scenePhase) { old, new in
            if new != .active { cancelCountdown() }
            if let event = ScenePhaseMapping.event(from: old, to: new) {
                store.send(event)
            }
        }
        .onChange(of: presentation.blocking) { _, new in
            if new != .none { cancelCountdown() }
        }
    }

    // MARK: - Question panel

    private var questionPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UICopy.questionCounter(store.state.questionIndex, store.state.deck.questions.count))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(store.currentQuestion.text)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            if let next = store.nextQuestionPreview {
                Text(next.text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        // Translucent black backing: white text stays ≥7:1 against any preview content.
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Timer

    @ViewBuilder
    private var timerRow: some View {
        if presentation.showsRecordingDot, let timerText = presentation.timerText {
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                Text(timerText)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.6), in: Capsule())
        }
    }

    // MARK: - Banner

    @ViewBuilder
    private var bannerRow: some View {
        switch presentation.banner {
        case .none:
            EmptyView()
        case .readAloud:
            bannerText(UICopy.readAloudBanner)
        case .noAudio:
            bannerText(UICopy.noAudioBanner)
        case let .paused(reason):
            bannerText(UICopy.pausedBanner(reason))
        }
    }

    private func bannerText(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack(spacing: 16) {
            primaryButton
            advanceButton
        }
        .frame(maxWidth: .infinity)
    }

    private var primaryButton: some View {
        let p = presentation.primary
        return Button(primaryLabel(p)) {
            switch p {
            case .record, .resume:
                startCountdown()
            case .cancelCountdown:
                cancelCountdown()
            case .pause:
                store.send(.tapPause)
            case .saving, .unavailable:
                break   // disabled
            }
        }
        .font(.title2)
        .frame(minWidth: 44, minHeight: 44)
        .disabled(p == .saving || p == .unavailable)
        .accessibilityLabel(primaryLabel(p))
    }

    private func primaryLabel(_ p: RecorderPresentation.Primary) -> String {
        switch p {
        case .record: UICopy.record
        case .pause: UICopy.pause
        case .resume: UICopy.resume
        case .saving: UICopy.saving
        case .cancelCountdown: UICopy.cancel
        case .unavailable: UICopy.record   // disabled; behind the blocking overlay
        }
    }

    private var advanceButton: some View {
        let a = presentation.advance
        return Button(advanceLabel(a)) {
            switch a {
            case .skip:
                store.send(.tapSkip)
            case .next:
                store.send(.tapNextQuestion)
            case .finish:
                Task { await model.endSession() }
            case .disabled:
                break
            }
        }
        .font(.title2)
        .frame(minWidth: 44, minHeight: 44)
        .disabled(a == .disabled)
        .accessibilityLabel(advanceLabel(a))
    }

    private func advanceLabel(_ a: RecorderPresentation.Advance) -> String {
        switch a {
        case .skip: UICopy.skip
        case .next: UICopy.next
        case .finish: UICopy.finish
        case .disabled: UICopy.next   // disabled; label is irrelevant to display
        }
    }

    // MARK: - Countdown

    /// 3-2-1 before record/resume. The store event is chosen from the phase re-READ at
    /// the end of the countdown, never the phase from when it started.
    private func startCountdown() {
        countdown = 3
        countdownTask = Task {
            do {
                while let value = countdown, value > 1 {
                    try await Task.sleep(for: .seconds(1))
                    countdown = value - 1
                }
                try await Task.sleep(for: .seconds(1))
            } catch {
                return   // cancelled: send nothing
            }
            countdown = nil
            switch store.state.phase {
            case .idle:
                store.send(.tapRecord)
            case .paused:
                store.send(.tapResume)
            case .recording, .finishing:
                break
            }
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdown = nil
    }

    @ViewBuilder
    private func countdownOverlay(_ text: String) -> some View {
        Text(text)
            .font(.largeTitle.bold().monospacedDigit())
            .foregroundStyle(.white)
            .padding(32)
            .background(.black.opacity(0.6), in: Circle())
    }

    // MARK: - Blocking overlay

    /// Opaque black, covers preview and controls; the "Done" toolbar button is in the
    /// navigation bar above this and stays usable when `canLeave`.
    @ViewBuilder
    private var blockingOverlay: some View {
        Color.black
            .ignoresSafeArea()
            .overlay {
                switch presentation.blocking {
                case .none:
                    EmptyView()
                case .preparing:
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(UICopy.preparing)
                            .font(.body)
                            .foregroundStyle(.white)
                    }
                case .notAuthorized:
                    VStack(spacing: 16) {
                        Text(UICopy.notAuthorizedTitle)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text(UICopy.notAuthorizedBody)
                            .font(.body)
                            .foregroundStyle(.white)
                        Button(UICopy.openSettings) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.title2)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel(UICopy.openSettings)
                    }
                    .padding()
                case .unavailable:
                    VStack(spacing: 16) {
                        Text(UICopy.unavailableTitle)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text(UICopy.unavailableBody)
                            .font(.body)
                            .foregroundStyle(.white)
                    }
                    .padding()
                }
            }
    }
}
