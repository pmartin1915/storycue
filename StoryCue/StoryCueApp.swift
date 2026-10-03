import SwiftUI

@main
struct StoryCueApp: App {
    #if DEBUG
    // `-StoryCueDemo` (ScreenshotTests only) launches the seeded mock demo; everything else
    // is production. The Release build compiles only the production line below.
    @State private var model = ProcessInfo.processInfo.arguments.contains("-StoryCueDemo")
        ? AppModel.demo()
        : AppModel.production()
    #else
    @State private var model = AppModel.production()
    #endif

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .task { await model.library.load() }
        }
    }
}
