import SwiftUI

struct DeckPickerView: View {
    let model: AppModel

    var body: some View {
        List {
            if model.library.storage.isLow {
                Section {
                    StorageBanner(availableBytes: model.library.storage.availableBytes)
                }
            }
            Section {
                ForEach(Deck.v1Decks) { deck in
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
            }
        }
        .navigationTitle(UICopy.deckPickerTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    LibraryView(model: model)
                } label: {
                    Text(UICopy.libraryButton)
                }
                .disabled(!model.library.isLoaded)
                .accessibilityIdentifier("libraryButton")
            }
        }
    }
}
