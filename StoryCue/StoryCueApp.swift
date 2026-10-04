import SwiftUI

@main
struct StoryCueApp: App {
    #if DEBUG
    // `-StoryCueDemo` (ScreenshotTests only) launches the seeded mock demo; everything else
    // is production. The Release build compiles only the production line below.
    private static let isDark: Bool = ProcessInfo.processInfo.arguments.contains("-StoryCueDark")
    private static let isAX5: Bool = ProcessInfo.processInfo.arguments.contains("-StoryCueAX5")
    @State private var model = ProcessInfo.processInfo.arguments.contains("-StoryCueDemo")
        ? AppModel.demo()
        : AppModel.production()
    #else
    @State private var model = AppModel.production()
    #endif

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            RootView(model: model)
                .preferredColorScheme(Self.isDark ? .dark : nil)
                .modifier(AccessibilitySizeModifier(isEnabled: Self.isAX5))
                .task { await model.library.load() }
            #else
            RootView(model: model)
                .task { await model.library.load() }
            #endif
        }
    }
}

#if DEBUG
private struct AccessibilitySizeModifier: ViewModifier {
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.dynamicTypeSize(.accessibility5)
        } else {
            content
        }
    }
}
#endif
