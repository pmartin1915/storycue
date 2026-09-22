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
}
