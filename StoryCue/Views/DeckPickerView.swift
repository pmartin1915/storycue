import SwiftUI

struct DeckPickerView: View {
    let model: AppModel

    var body: some View {
        List(Deck.v1Decks) { deck in
            NavigationLink {
                ConsentView(deck: deck, model: model)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deck.title)
                        .font(.title2)
                    Text(UICopy.questionCount(deck.questions.count))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .accessibilityLabel("\(deck.title), \(UICopy.questionCount(deck.questions.count))")
        }
        .navigationTitle(UICopy.deckPickerTitle)
    }
}
