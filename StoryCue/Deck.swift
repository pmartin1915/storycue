import Foundation

enum DeckMode: String, Codable, Sendable { case sequential, roundRobin }

struct Question: Identifiable, Codable, Equatable, Sendable {
    let id: String          // "grandparents.001" etc — stable, referenced by tests
    let text: String         // v1: "// TODO copy" placeholder; real copy is a later pass
    let isVHPSourced: Bool    // true only on the optional veterans deck (public-domain VHP text)
}

struct Deck: Identifiable, Codable, Equatable, Sendable {
    let id: String            // "grandparents" | "parents" | "kids" | "couples" | "holiday-table"
    let title: String
    let mode: DeckMode          // .roundRobin only for "holiday-table"; .sequential otherwise
    let questions: [Question]
    let isIncluded: Bool         // true for all five v1 decks (SYNTHESIS Q7: free, all decks included)
}
