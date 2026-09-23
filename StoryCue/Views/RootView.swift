import SwiftUI

struct RootView: View {
    @Bindable var model: AppModel

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
        }
    }
}
