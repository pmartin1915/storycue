import SwiftUI

struct RootView: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            DeckPickerView(model: model)
                .navigationDestination(
                    isPresented: Binding(
                        get: { model.active != nil },
                        set: { _ in }
                    )
                ) {
                    if let active = model.active {
                        RecorderView(session: active, model: model)
                            // A fresh view per session so its preview connects to the new
                            // capture service instead of reusing the previous one's
                            // (black) representable.
                            .id(ObjectIdentifier(active.store))
                    }
                }
                .navigationDestination(item: $model.finishedSessionID) { id in
                    SessionDetailView(sessionID: id, model: model, showsCompletion: true)
                }
        }
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(text: toast.text)
                    // Clear of a screen's bottom action bar (the consent card's We're ready).
                    .padding(.bottom, DesignTokens.Spacing.xl * 4)
                    .transition(.opacity)
                    .id(toast.id)
            }
        }
        .animation(reduceMotion ? nil : DesignTokens.Motion.fade, value: model.toast)
        .task(id: model.toast?.id) {
            guard let shown = model.toast else { return }
            AccessibilityNotification.Announcement(shown.text).post()
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, model.toast?.id == shown.id else { return }
            model.toast = nil
        }
    }
}

/// The confirmation capsule. Informs only: it never takes a tap.
struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DesignTokens.Spacing.l)
            .padding(.vertical, DesignTokens.Spacing.s)
            // The over-camera backing, not a material: a light material vanished on the
            // light grouped background (comeup-06 review shot). White on it clears 7:1 anywhere.
            .background(DesignTokens.overCameraFill, in: Capsule())
            .padding(.horizontal, DesignTokens.Spacing.l)
            .allowsHitTesting(false)
            .accessibilityIdentifier("toast")
    }
}
