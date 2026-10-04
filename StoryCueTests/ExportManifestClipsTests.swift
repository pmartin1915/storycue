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

    // MARK: - S2c: playbackSources

    /// One clip holding all four outcome kinds plays exactly the `.saved` and
    /// `.failed(kept: true)` segments, in order, at their `SegmentFiles` URLs — never
    /// the outcome's stored `url`.
    func testPlaybackSourcesUsesManifestRules() {
        let deck = Deck.v1Decks[0]
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        func segment(_ outcome: SegmentOutcome?) -> Segment {
            Segment(id: UUID(), questionID: deck.questions[0].id, startedAt: date, endReason: nil, outcome: outcome)
        }
        let saved = segment(.saved(url: URL(fileURLWithPath: "/unused")))
        let keptFailed = segment(.failed(kept: true))
        let unkeptFailed = segment(.failed(kept: false))
        let undecided = segment(nil)
        let record = SessionRecord(
            id: UUID(),
            deckID: deck.id,
            deckTitle: deck.title,
            startedAt: date,
            clips: [Clip(questionID: deck.questions[0].id, segments: [saved, keptFailed, unkeptFailed, undecided])],
            isFinished: true
        )

        let sources = playbackSources(for: record, questionID: deck.questions[0].id, in: directory)

        XCTAssertEqual(sources, [
            SegmentFiles.url(for: saved.id, in: directory),
            SegmentFiles.url(for: keptFailed.id, in: directory)
        ])
    }

    func testPlaybackSourcesUnknownQuestionIsEmpty() {
        let deck = Deck.v1Decks[0]
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let saved = Segment(
            id: UUID(),
            questionID: deck.questions[0].id,
            startedAt: date,
            endReason: nil,
            outcome: .saved(url: URL(fileURLWithPath: "/unused"))
        )
        let record = SessionRecord(
            id: UUID(),
            deckID: deck.id,
            deckTitle: deck.title,
            startedAt: date,
            clips: [Clip(questionID: deck.questions[0].id, segments: [saved])],
            isFinished: true
        )

        let sources = playbackSources(
            for: record,
            questionID: "no-such-question",
            in: FileManager.default.temporaryDirectory
        )

        XCTAssertTrue(sources.isEmpty)
    }
}
