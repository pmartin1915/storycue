import XCTest
@testable import StoryCue

final class DeckDataTests: XCTestCase {
    func testAllFiveV1DecksExist() {
        let ids = Deck.v1Decks.map(\.id)
        XCTAssertEqual(ids, ["grandparents", "parents", "kids", "couples", "holiday-table"])
    }

    func testAllQuestionIDsUnique() {
        let allIDs = Deck.v1Decks.flatMap(\.questions).map(\.id)
        XCTAssertEqual(Set(allIDs).count, allIDs.count)
    }

    func testHolidayTableDeckUsesRoundRobinMode() {
        for deck in Deck.v1Decks {
            if deck.id == "holiday-table" {
                XCTAssertEqual(deck.mode, .roundRobin)
            } else {
                XCTAssertEqual(deck.mode, .sequential, "\(deck.id) must be sequential")
            }
        }
    }

    func testAllV1DecksAreIncluded() {
        XCTAssertTrue(Deck.v1Decks.allSatisfy(\.isIncluded))
    }

    func testEveryDeckHasTeaser() {
        for deck in Deck.v1Decks {
            let teaser = UICopy.deckTeaser(deck.id)
            XCTAssertFalse(teaser.isEmpty, "\(deck.id) needs a teaser")
            XCTAssertLessThanOrEqual(teaser.count, 60, "\(deck.id) teaser exceeds 60 characters")
            XCTAssertFalse(teaser.hasSuffix("."), "\(deck.id) teaser must not end in a period")
        }
    }

    func testDeckSymbolsAreDistinct() {
        let symbols = Deck.v1Decks.map { DesignTokens.deckSymbol($0.id) }
        let defaultSymbol = DesignTokens.deckSymbol("unknown-deck")
        XCTAssertEqual(Set(symbols).count, 5)
        XCTAssertTrue(symbols.allSatisfy { $0 != defaultSymbol })
    }

    func testEachV1DeckHasBetweenEightAndTwelveQuestions() {
        for deck in Deck.v1Decks {
            XCTAssertTrue(
                (8...12).contains(deck.questions.count),
                "\(deck.id) has \(deck.questions.count) questions; expected 8–12"
            )
        }
    }

    func testNoV1QuestionsAreVHPSourced() {
        let questions = Deck.v1Decks.flatMap(\.questions)
        XCTAssertFalse(questions.contains(where: \.isVHPSourced))
    }

    // S4 copy lints (docs/S4-DECK-COPY-SPEC.md §4).

    private var allQuestions: [Question] { Deck.v1Decks.flatMap(\.questions) }

    func testNoV1QuestionIsPlaceholder() {
        for q in allQuestions {
            XCTAssertFalse(q.text.contains("TODO"), "\(q.id) is placeholder copy")
            XCTAssertFalse(q.text.isEmpty, "\(q.id) is empty")
            XCTAssertEqual(q.text, q.text.trimmingCharacters(in: .whitespacesAndNewlines), "\(q.id) has stray whitespace")
        }
    }

    func testEveryV1QuestionEndsWithQuestionMark() {
        for q in allQuestions {
            XCTAssertTrue(q.text.hasSuffix("?"), "\(q.id) must end with ?")
        }
    }

    func testEveryV1QuestionFitsTheOuterDisplay() {
        for q in allQuestions {
            let words = q.text.split(whereSeparator: \.isWhitespace).count
            XCTAssertLessThanOrEqual(words, 15, "\(q.id) has \(words) words; max 15")
            XCTAssertLessThanOrEqual(q.text.count, 80, "\(q.id) has \(q.text.count) characters; max 80")
        }
    }

    func testNoV1QuestionOpensAsYesNo() {
        let yesNoOpeners: Set<String> = [
            "did", "do", "does", "have", "has", "is", "are", "was", "were", "can", "could",
            "would", "will", "should", "am", "had", "don't", "doesn't", "didn't", "isn't",
            "aren't", "wasn't", "weren't", "won't", "wouldn't", "hasn't", "haven't",
        ]
        for q in allQuestions {
            let first = String(q.text.split(whereSeparator: \.isWhitespace).first ?? "")
            let opener = String(first.lowercased().filter { $0.isLetter || $0 == "'" })
            XCTAssertFalse(yesNoOpeners.contains(opener), "\(q.id) opens with yes/no word \"\(opener)\"")
        }
    }

    func testV1QuestionTextIsUniqueAcrossDecks() {
        let texts = allQuestions.map(\.text)
        XCTAssertEqual(Set(texts).count, texts.count)
    }

    func testEveryV1QuestionIsPlainASCII() {
        for q in allQuestions {
            XCTAssertTrue(q.text.unicodeScalars.allSatisfy(\.isASCII), "\(q.id) must be plain ASCII")
        }
    }
}
