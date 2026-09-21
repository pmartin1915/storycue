import SwiftUI

@main
struct StoryCueApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("StoryCue")
                .font(.largeTitle.bold())
            Text(DuoSupport.buildDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
