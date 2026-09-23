import XCTest
@testable import StoryCue

/// ExportPlanner tests (S3 spec §6): pure, no disk — sizes come from a dictionary.
final class ExportPlannerTests: XCTestCase {
    private let deck = Deck.v1Decks[0]   // "Grandparents", questions grandparents.001...
    private let segmentDirectory = URL(fileURLWithPath: "/segments", isDirectory: true)

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    /// 2026-10-02 12:00:00 UTC.
    private var sessionDate: Date {
        DateComponents(
            calendar: utcCalendar,
            timeZone: utcCalendar.timeZone,
            year: 2026, month: 10, day: 2, hour: 12
        ).date ?? Date(timeIntervalSince1970: 0)
    }

    private func makeSegment(
        id: UUID = UUID(),
        questionID: String,
        outcome: SegmentOutcome? = nil
    ) -> Segment {
        Segment(id: id, questionID: questionID, startedAt: Date(), endReason: nil, outcome: outcome)
    }

    private func plan(
        entries: [ClipManifestEntry],
        sizes: [URL: Int64],
        unit: ExportUnit = .perClip
    ) -> ExportPlan {
        ExportPlanner.plan(
            entries: entries,
            deck: deck,
            sessionDate: sessionDate,
            unit: unit,
            segmentDirectory: segmentDirectory,
            fileSize: { sizes[$0] },
            calendar: utcCalendar
        )
    }

    func testPerClipOneOutputPerEntryInManifestOrder() {
        let q1 = deck.questions[0].id, q2 = deck.questions[1].id, q3 = deck.questions[2].id
        let s1 = makeSegment(questionID: q1), s2 = makeSegment(questionID: q1)
        let s3 = makeSegment(questionID: q2), s4 = makeSegment(questionID: q3)
        let entries = [
            ClipManifestEntry(questionID: q1, segments: [s1, s2]),
            ClipManifestEntry(questionID: q2, segments: [s3]),
            ClipManifestEntry(questionID: q3, segments: [s4]),
        ]
        let sizes = [s1, s2, s3, s4].reduce(into: [URL: Int64]()) {
            $0[SegmentFiles.url(for: $1.id, in: segmentDirectory)] = 10
        }

        let result = plan(entries: entries, sizes: sizes)

        XCTAssertEqual(result.outputs.count, 3)
        XCTAssertEqual(result.outputs.map(\.questionIDs), [[q1], [q2], [q3]])
        XCTAssertEqual(result.outputs[0].sources, [
            SegmentFiles.url(for: s1.id, in: segmentDirectory),
            SegmentFiles.url(for: s2.id, in: segmentDirectory),
        ])
        XCTAssertEqual(result.outputs[1].sources, [SegmentFiles.url(for: s3.id, in: segmentDirectory)])
        XCTAssertEqual(result.outputs[2].sources, [SegmentFiles.url(for: s4.id, in: segmentDirectory)])
        XCTAssertEqual(
            result.outputs.map(\.fileName),
            [
                "StoryCue - Grandparents - 2026-10-02 - Q01.mov",
                "StoryCue - Grandparents - 2026-10-02 - Q02.mov",
                "StoryCue - Grandparents - 2026-10-02 - Q03.mov",
            ]
        )
        XCTAssertTrue(result.dropped.isEmpty)
    }

    func testWholeSessionOneOutputAllSourcesInOrder() {
        let q1 = deck.questions[0].id, q2 = deck.questions[1].id
        let s1 = makeSegment(questionID: q1), s2 = makeSegment(questionID: q1)
        let s3 = makeSegment(questionID: q2), s4 = makeSegment(questionID: q2)
        let entries = [
            ClipManifestEntry(questionID: q1, segments: [s1, s2]),
            ClipManifestEntry(questionID: q2, segments: [s3, s4]),
        ]
        let sizes = [s1, s2, s3, s4].reduce(into: [URL: Int64]()) {
            $0[SegmentFiles.url(for: $1.id, in: segmentDirectory)] = 10
        }

        let result = plan(entries: entries, sizes: sizes, unit: .wholeSession)

        XCTAssertEqual(result.outputs.count, 1)
        XCTAssertEqual(result.outputs[0].questionIDs, [q1, q2])
        XCTAssertEqual(result.outputs[0].sources, [
            SegmentFiles.url(for: s1.id, in: segmentDirectory),
            SegmentFiles.url(for: s2.id, in: segmentDirectory),
            SegmentFiles.url(for: s3.id, in: segmentDirectory),
            SegmentFiles.url(for: s4.id, in: segmentDirectory),
        ])
        XCTAssertEqual(result.outputs[0].fileName, "StoryCue - Grandparents - 2026-10-02.mov")
        XCTAssertTrue(result.dropped.isEmpty)
    }

    func testSourcesDerivedFromSegmentIDNotStoredURL() {
        let q1 = deck.questions[0].id
        let id = UUID()
        // A .saved(url:) pointing at a path that doesn't exist (e.g. an old container).
        let storedURL = URL(fileURLWithPath: "/nonexistent/container/\(id.uuidString).mov")
        let segment = makeSegment(id: id, questionID: q1, outcome: .saved(url: storedURL))
        let derivedURL = SegmentFiles.url(for: id, in: segmentDirectory)
        let entries = [ClipManifestEntry(questionID: q1, segments: [segment])]

        let result = plan(entries: entries, sizes: [derivedURL: 10])

        XCTAssertEqual(result.outputs.count, 1)
        XCTAssertEqual(result.outputs[0].sources, [derivedURL])
        XCTAssertFalse(result.outputs[0].sources.contains(storedURL))
    }

    func testMissingFileDroppedWithReason() {
        let q1 = deck.questions[0].id
        let missing = makeSegment(questionID: q1)
        let present = makeSegment(questionID: q1)
        let entries = [ClipManifestEntry(questionID: q1, segments: [missing, present])]
        let sizes = [SegmentFiles.url(for: present.id, in: segmentDirectory): 10]

        let result = plan(entries: entries, sizes: sizes)

        XCTAssertEqual(result.dropped, [DroppedSegment(
            segmentID: missing.id,
            questionID: q1,
            reason: .missingFile
        )])
        XCTAssertEqual(result.outputs[0].sources, [SegmentFiles.url(for: present.id, in: segmentDirectory)])
    }

    func testDroppedIsInManifestOrderAcrossEntries() {
        let q1 = deck.questions[0].id, q2 = deck.questions[1].id
        let keepA = makeSegment(questionID: q1)
        let dropB = makeSegment(questionID: q1)
        let dropC = makeSegment(questionID: q2)
        let keepD = makeSegment(questionID: q2)
        let entries = [
            ClipManifestEntry(questionID: q1, segments: [keepA, dropB]),
            ClipManifestEntry(questionID: q2, segments: [dropC, keepD]),
        ]
        let sizes: [URL: Int64] = [keepA, keepD].reduce(into: [:]) {
            $0[SegmentFiles.url(for: $1.id, in: segmentDirectory)] = 10
        }

        let result = plan(entries: entries, sizes: sizes)

        XCTAssertEqual(result.dropped, [
            DroppedSegment(segmentID: dropB.id, questionID: q1, reason: .missingFile),
            DroppedSegment(segmentID: dropC.id, questionID: q2, reason: .missingFile),
        ])
        XCTAssertEqual(result.outputs.count, 2)
    }

    func testEmptyFileDroppedWithReason() {
        let q1 = deck.questions[0].id
        let empty = makeSegment(questionID: q1)
        let entries = [ClipManifestEntry(questionID: q1, segments: [empty])]
        let sizes = [SegmentFiles.url(for: empty.id, in: segmentDirectory): 0]

        let result = plan(entries: entries, sizes: sizes)

        XCTAssertEqual(result.outputs.count, 0)
        XCTAssertEqual(result.dropped, [DroppedSegment(
            segmentID: empty.id,
            questionID: q1,
            reason: .emptyFile
        )])
    }

    func testEntryWithAllSourcesDroppedProducesNoOutput() {
        let q1 = deck.questions[0].id, q2 = deck.questions[1].id
        let gone1 = makeSegment(questionID: q1)
        let gone2 = makeSegment(questionID: q1)
        let ok = makeSegment(questionID: q2)
        let entries = [
            ClipManifestEntry(questionID: q1, segments: [gone1, gone2]),
            ClipManifestEntry(questionID: q2, segments: [ok]),
        ]
        let sizes = [SegmentFiles.url(for: ok.id, in: segmentDirectory): 10]

        let result = plan(entries: entries, sizes: sizes)

        XCTAssertEqual(result.outputs.count, 1)
        XCTAssertEqual(result.outputs[0].questionIDs, [q2])
        XCTAssertEqual(result.dropped, [
            DroppedSegment(segmentID: gone1.id, questionID: q1, reason: .missingFile),
            DroppedSegment(segmentID: gone2.id, questionID: q1, reason: .missingFile),
        ])
    }

    func testFailedKeptSegmentsAreFlagged() {
        let q1 = deck.questions[0].id
        let saved = makeSegment(questionID: q1, outcome: .saved(url: URL(fileURLWithPath: "/x.mov")))
        let keptID = UUID()
        let kept = makeSegment(id: keptID, questionID: q1, outcome: .failed(kept: true))
        let entries = [ClipManifestEntry(questionID: q1, segments: [saved, kept])]
        let sizes = [saved, kept].reduce(into: [URL: Int64]()) {
            $0[SegmentFiles.url(for: $1.id, in: segmentDirectory)] = 10
        }

        let result = plan(entries: entries, sizes: sizes)

        XCTAssertEqual(result.outputs[0].flaggedSegmentIDs, [keptID])
    }

    func testTotalSourceBytesExcludesDropped() {
        let q1 = deck.questions[0].id
        let a = makeSegment(questionID: q1)
        let missing = makeSegment(questionID: q1)
        let b = makeSegment(questionID: q1)
        let entries = [ClipManifestEntry(questionID: q1, segments: [a, missing, b])]
        let sizes: [URL: Int64] = [
            SegmentFiles.url(for: a.id, in: segmentDirectory): 100,
            SegmentFiles.url(for: b.id, in: segmentDirectory): 50,
        ]

        let result = plan(entries: entries, sizes: sizes)

        XCTAssertEqual(result.totalSourceBytes, 150)
        XCTAssertEqual(result.outputs[0].sources.count, 2)
    }

    func testFileNameUsesDeckQuestionNumber() {
        let name = ExportPlanner.fileName(
            deck: deck,
            questionID: deck.questions[2].id,   // third question → Q03
            sessionDate: sessionDate,
            calendar: utcCalendar
        )
        XCTAssertEqual(name, "StoryCue - Grandparents - 2026-10-02 - Q03.mov")
    }

    func testFileNameUnknownQuestionIsQ00() {
        let name = ExportPlanner.fileName(
            deck: deck,
            questionID: "not-in-the-deck",
            sessionDate: sessionDate,
            calendar: utcCalendar
        )
        XCTAssertEqual(name, "StoryCue - Grandparents - 2026-10-02 - Q00.mov")
    }

    func testFileNameSanitizesReservedCharacters() {
        let dirtyDeck = Deck(
            id: "dirty",
            title: "A/B\\C:D*E?F\"G<H>I|J\u{0001}",
            mode: .sequential,
            questions: [Question(id: "dirty.001", text: "// TODO copy", isVHPSourced: false)],
            isIncluded: true
        )
        let name = ExportPlanner.fileName(
            deck: dirtyDeck,
            questionID: "dirty.001",
            sessionDate: sessionDate,
            calendar: utcCalendar
        )
        XCTAssertEqual(name, "StoryCue - A-B-C-D-E-F-G-H-I-J- - Q01.mov")
        for banned in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"] {
            XCTAssertFalse(name.contains(banned), "name must not contain \(banned)")
        }
        XCTAssertFalse(name.contains("\u{0001}"))
    }

    func testFileNameUsesInjectedTimeZone() {
        // 2026-10-02T01:00:00Z: UTC still on Oct 2, New York (UTC-4) still on Oct 1.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York") ?? utc.timeZone
        let instant = DateComponents(calendar: utc, year: 2026, month: 10, day: 2, hour: 1).date
            ?? Date(timeIntervalSince1970: 0)

        let utcName = ExportPlanner.fileName(
            deck: deck, questionID: nil, sessionDate: instant, calendar: utc
        )
        let newYorkName = ExportPlanner.fileName(
            deck: deck, questionID: nil, sessionDate: instant, calendar: newYork
        )

        XCTAssertEqual(utcName, "StoryCue - Grandparents - 2026-10-02.mov")
        XCTAssertEqual(newYorkName, "StoryCue - Grandparents - 2026-10-01.mov")
        XCTAssertNotEqual(utcName, newYorkName)
    }
}
