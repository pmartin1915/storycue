import SwiftUI

@main
struct StoryCueApp: App {
    @State private var model = AppModel.production()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
