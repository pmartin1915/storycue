import XCTest
@testable import StoryCue

final class ExportManifestClipsTests: XCTestCase {
    func testManifestForClipsMatchesState() {
        let deck = Deck.v1Decks[0]
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        func segment(_ question: String, _ outcome: SegmentOutcome?) -> Segment {
            Segment(id: UUID(), questionID: question, startedAt: date, endReason: nil, outcome: outcome)
        }
        let saved = segment(deck.questions[0].id, .saved(url: URL(fileURLWithPath: "/unused")))
        let keptFailed = segment(deck.questions[1].id, .failed(kept: true))
        let unkeptFailed = segment(deck.questions[2].id, .failed(kept: false))
        let undecided = segment(deck.questions[3].id, nil)
        let clips = [
            Clip(questionID: deck.questions[0].id, segments: [saved]),
            Clip(questionID: deck.questions[1].id, segments: [keptFailed]),
            Clip(questionID: deck.questions[2].id, segments: [unkeptFailed]),
            Clip(questionID: deck.questions[3].id, segments: [undecided]),
        ]
        let state = SessionState(
            deck: deck,
            questionIndex: 0,
            phase: .idle,
            clips: clips,
            hinge: nil,
            backgroundTaskActive: false
        )

        let viaState = exportManifest(for: state)
        let viaClips = exportManifest(for: clips)

        XCTAssertEqual(viaState, viaClips)
        XCTAssertEqual(viaClips.map(\.questionID), [deck.questions[0].id, deck.questions[1].id])
    }
}
