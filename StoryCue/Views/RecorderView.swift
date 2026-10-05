import SwiftUI
import UIKit

struct RecorderView: View {
    let session: AppModel.ActiveSession
    let model: AppModel

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Where the question card rests, as a distance down from the top of its slot. Not
    /// persisted: RootView gives each session a fresh RecorderView, so every session starts
    /// with the card at the top.
    @State private var questionRestOffset: CGFloat = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var questionSlotHeight: CGFloat = 0
    @State private var questionCardHeight: CGFloat = 0
    @State private var questionDrops = 0          // haptic trigger: one tick per deliberate move

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
            previewBackdrop

            VStack(spacing: 16) {
                // The question card sits at the top or just above the controls (the user
                // drags it off the subject's face); the controls never move.
                questionArea
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
        .sensoryFeedback(.impact(weight: .medium), trigger: presentation.primary) { old, new in
            (old == .pause) != (new == .pause)
        }
        .sensoryFeedback(.selection, trigger: store.state.questionIndex)
        .sensoryFeedback(.selection, trigger: questionDrops)
        .task { store.startTicker() }
        .onDisappear { cancelCountdown() }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(UICopy.done) {
                    cancelCountdown()
                    Task { await model.endSession() }
                }
                .disabled(!presentation.canLeave)
                .accessibilityLabel(UICopy.done)
                .accessibilityIdentifier("doneButton")
            }
        }
        .onChange(of: scenePhase) { old, new in
            if new != .active {
                cancelCountdown()
                dragTranslation = 0     // an interrupted drag may never reach onEnded
            }
            if let event = ScenePhaseMapping.event(from: old, to: new) {
                store.send(event)
            }
        }
        .onChange(of: presentation.blocking) { _, new in
            if new != .none { cancelCountdown() }
        }
    }

    /// The camera feed, or — demo mode only (the simulator has no camera) — a soft dark
    /// warm gradient so the recorder screenshot doesn't show a black void.
    #if DEBUG
    @ViewBuilder
    private var previewBackdrop: some View {
        if model.isDemo {
            LinearGradient(
                colors: [
                    DesignTokens.demoBackdropTop,
                    DesignTokens.demoBackdropBottom,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        } else {
            CameraPreview(source: session.capture.previewSource)
                .ignoresSafeArea()
        }
    }
    #else
    private var previewBackdrop: some View {
        CameraPreview(source: session.capture.previewSource)
            .ignoresSafeArea()
    }
    #endif

    // MARK: - Question panel

    /// The card at its natural height when it fits, so it can sit anywhere in the slot; in a
    /// ScrollView when it doesn't (largest accessibility sizes on a small screen), so it can
    /// never push Record/Next off screen. Only the fitting card takes the drag: inside the
    /// ScrollView a drag would fight scrolling, so there the handle button moves it.
    private var questionArea: some View {
        ViewThatFits(in: .vertical) {
            // The slot fills the space above the controls; the card is pinned to its top and
            // offset down by where the user left it. (Spacers around the area did not work:
            // the area's layout priority took all the free space and the Spacer got 0.)
            questionPanel(movable: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { questionCardHeight = $0 }
                .offset(y: questionOffset)
                .gesture(questionDrag)
                .frame(maxHeight: .infinity, alignment: .top)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { questionSlotHeight = $0 }
                // Keep the resting spot inside the travel, so the next drag starts where the
                // card actually is.
                .onChange(of: questionTravel) { _, _ in
                    questionRestOffset = clampedQuestionOffset(questionRestOffset)
                }
            // A card this tall fills the whole area, so there is nowhere to move it: no handle.
            ScrollView {
                questionPanel(movable: false)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .layoutPriority(1)
    }

    /// How far the card can travel: the slot minus the card. Shrinks when a banner appears or
    /// the next question is longer, and every offset below is clamped to it.
    private var questionTravel: CGFloat { max(0, questionSlotHeight - questionCardHeight) }

    private func clampedQuestionOffset(_ y: CGFloat) -> CGFloat { min(max(y, 0), questionTravel) }

    private var questionOffset: CGFloat { clampedQuestionOffset(questionRestOffset + dragTranslation) }

    /// In the lower half of its travel: the handle offers "to top", otherwise "to bottom".
    private var questionIsLow: Bool { questionTravel > 0 && questionOffset > questionTravel / 2 }

    /// Follows the finger anywhere in the slot and stays where it is let go.
    private var questionDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                questionRestOffset = clampedQuestionOffset(questionRestOffset + value.translation.height)
                dragTranslation = 0
                questionDrops += 1
            }
    }

    private func toggleQuestionPosition() {
        withAnimation(reduceMotion ? nil : DesignTokens.Motion.morph) {
            questionRestOffset = questionIsLow ? 0 : questionTravel
        }
        questionDrops += 1
    }

    private var questionHandle: some View {
        Button(action: toggleQuestionPosition) {
            Capsule()
                .fill(.white.opacity(0.6))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -8)              // 44 pt to touch, 28 pt of card height
        .accessibilitySortPriority(-1)       // VoiceOver reads the question first
        .accessibilityLabel(questionIsLow ? UICopy.moveQuestionToTop : UICopy.moveQuestionToBottom)
        .accessibilityIdentifier("questionHandle")
    }

    private func questionPanel(movable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if movable { questionHandle }
            Text(UICopy.questionCounter(store.state.questionIndex, store.state.deck.questions.count))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
            Text(store.currentQuestion.text)
                .font(.largeTitle.bold())
                .fontDesign(DesignTokens.questionFontDesign)
                .foregroundStyle(.white)
            if let next = store.nextQuestionPreview {
                Text(next.text)
                    .font(.callout)
                    .fontDesign(DesignTokens.questionFontDesign)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        // Translucent black backing: white text stays ≥7:1 even over a pure-white feed
        // (70% black over white ≈ 8.5:1; 60% was only ≈ 5.7:1). Secondary lines use opaque-ish white, not .secondary, which
        // is translucent gray and drops below 3:1 over a bright feed.
        .background(DesignTokens.overCameraFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("questionPanel")
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
            .background(DesignTokens.overCameraFill, in: Capsule())
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
            .background(DesignTokens.overCameraFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // Side by side, no spacer column: stacking cost the question card most of its
            // height at AX5 (review screenshot ax5-03-recorder). Control labels cap at AX2;
            // the question above still scales fully.
            HStack(spacing: DesignTokens.Spacing.l) {
                primaryButton
                advanceButton
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        } else {
            HStack(spacing: DesignTokens.Spacing.l) {
                Color.clear
                    .frame(maxWidth: .infinity)
                primaryButton
                    .frame(maxWidth: .infinity)
                advanceButton
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var primaryButton: some View {
        let p = presentation.primary
        return RecordButton(primary: p, label: primaryLabel(p)) {
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
        return Button {
            switch a {
            case .skip:
                store.send(.tapSkip)
            case .next:
                store.send(.tapNextQuestion)
            case .finish:
                cancelCountdown()
                Task { await model.endSession() }
            case .disabled:
                break
            }
        } label: {
            Text(advanceLabel(a))
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.m)
                .padding(.vertical, DesignTokens.Spacing.s)
                .frame(minHeight: 44)
                .background(DesignTokens.overCameraFill, in: Capsule())
        }
        .buttonStyle(.plain)
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
        // A second activation before the view re-renders must not orphan a running task
        // that cancelCountdown() could no longer reach.
        guard countdownTask == nil else { return }
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
            countdownTask = nil
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
            .background(DesignTokens.overCameraFill, in: Circle())
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
