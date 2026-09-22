import Foundation

extension Deck {
    /// The five v1 decks from PLAN §2. All included in v1 (SYNTHESIS Q7: free, all decks
    /// included). Question text is `// TODO copy` placeholder — real copy is a separate,
    /// later pass, so DeckDataTests checks shape only.
    static let v1Decks: [Deck] = [
        Deck(
            id: "grandparents",
            title: "Grandparents",
            mode: .sequential,
            questions: (1...10).map {
                Question(id: String(format: "grandparents.%03d", $0), text: "// TODO copy", isVHPSourced: false)
            },
            isIncluded: true
        ),
        Deck(
            id: "parents",
            title: "Parents",
            mode: .sequential,
            questions: (1...10).map {
                Question(id: String(format: "parents.%03d", $0), text: "// TODO copy", isVHPSourced: false)
            },
            isIncluded: true
        ),
        Deck(
            id: "kids",
            title: "Kids Ask the Grownups",
            mode: .sequential,
            questions: (1...10).map {
                Question(id: String(format: "kids.%03d", $0), text: "// TODO copy", isVHPSourced: false)
            },
            isIncluded: true
        ),
        Deck(
            id: "couples",
            title: "Couples",
            mode: .sequential,
            questions: (1...10).map {
                Question(id: String(format: "couples.%03d", $0), text: "// TODO copy", isVHPSourced: false)
            },
            isIncluded: true
        ),
        Deck(
            id: "holiday-table",
            title: "Holiday Table",
            mode: .roundRobin,
            questions: (1...10).map {
                Question(id: String(format: "holiday-table.%03d", $0), text: "// TODO copy", isVHPSourced: false)
            },
            isIncluded: true
        ),
    ]
}
