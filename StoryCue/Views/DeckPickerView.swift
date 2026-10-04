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
                        DeckRowLabel(deckID: deck.id, title: deck.title) {
                            Text(UICopy.deckTeaser(deck.id))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel(
                        "\(deck.title), \(UICopy.deckTeaser(deck.id)), \(UICopy.questionCount(deck.questions.count))"
                    )
                    .accessibilityIdentifier("deck.\(deck.id)")
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
