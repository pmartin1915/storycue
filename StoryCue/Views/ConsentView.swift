import SwiftUI

/// The consent card AND the permission-priming screen: the system camera/mic prompts
/// appear only after the confirm tap, with this explanation already on screen.
struct ConsentView: View {
    let deck: Deck
    let model: AppModel

    @State private var isBeginning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(UICopy.consentTitle)
                    .font(.largeTitle.bold())

                Text(UICopy.consentBody)
                    .font(.body)

                // The read-aloud line, in a quoted callout.
                Text("\u{201C}\(UICopy.readAloudLine)\u{201D}")
                    .font(.callout)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                Text(UICopy.privacyNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(UICopy.consentConfirm) {
                    isBeginning = true
                    Task { await model.beginSession(deck: deck) }
                }
                .font(.title2)
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(isBeginning)
                .accessibilityLabel(UICopy.consentConfirm)
            }
            .padding()
        }
        .navigationTitle(deck.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
