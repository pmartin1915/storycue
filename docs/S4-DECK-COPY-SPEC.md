# S4 spec — deck copy (a submission gate)

_Written 2026-09-30. Step S4 of `docs/STRATEGY-2026-09-22.md` ("5 decks × 8–12 original
questions, rules from SYNTHESIS Q7; Kimi readability pass; no StoryCorps text. No archive
ships with `// TODO copy`"). Same contract as S1–S3: every file, string and test name is fixed
here so the executor types, it doesn't author. The copy itself is the deliverable and is
written out in full in section 2; the executor copies it byte for byte._

## Scope

**In:** the question text of the five v1 decks in `StoryCue/Decks.swift`; two stale comments
(`StoryCue/Deck.swift` line 7, the doc comment in `StoryCue/Decks.swift`); five new tests in
`StoryCueTests/DeckDataTests.swift`.

**Out:** deck IDs, deck titles, deck order, deck modes, `isIncluded`, question IDs, question
counts, `isVHPSourced`, the `Deck`/`Question` types, `UICopy`, every view, `project.yml`,
`.github/`, `docs/`. The optional VHP veterans deck (SYNTHESIS Q7) is not in S4. Copy is
data only: no layout or font change (Atkinson Hyperlegible stays a Kimi layout question).

**Nothing persists question text.** The ledger, `Clip`, `Segment` and the export manifest
carry `questionID` and the index only (`SegmentLedger.swift`, `SessionMachine.swift`,
`ExportPlan.swift`), so changing text can't strand a recording. IDs and counts must not change:
every test file pins `Deck.v1Decks[0]` (Grandparents) and `ExportPlannerTests` indexes
`questions[2]` → `Q03`.

## 1. Rules the copy follows (SYNTHESIS Q7 + PLAN §2)

1. **Every question asks for a story, not a fact.** Sensory, scene-setting or "what happened"
   prompts (PROMPT-B §2: open-ended, drawing on senses, emotions, relationships). No dates,
   counts, places-of-birth, or yes/no openers.
2. **Original wording only.** No StoryCorps "Great Questions" phrasing (copyrighted / CC-NC,
   PROMPT-B §2). Checked by hand against the familiar list (earliest memory, happiest/saddest
   moment, most important person, proudest of, how would you like to be remembered, how did
   you know they were "the one", advice for young couples, anything you've never told me).
   None of those phrasings appear; where a topic overlaps (how a couple met), the wording is
   new. Topics themselves are not copyrightable (PROMPT-B §2).
3. **Readable on the outer display:** 48–60 pt at 4–6 words a line, so **at most 15 words and
   80 characters** (3–4 lines on the outer view; fits `.largeTitle` on the inner view with the
   next-question preview below it).
4. **Every question ends with `?`** and is plain ASCII (straight apostrophes, matching `UICopy`).
5. **Addressed to the person on camera** in the second person. "I/me/my/we/us" means the
   person filming (a child in Parents/Kids, the family in Holiday Table).
6. **Holiday Table is round-robin:** every question must be answerable by anyone at the table,
   any age, without putting one person on the spot. Nothing about grief or health in any deck's
   opening question; heavier questions sit in the back half of a deck.
7. **Kids Ask the Grownups** uses words a seven-year-old can read aloud.

## 2. The copy (exact text, in deck order; IDs unchanged)

### Grandparents (`grandparents.001`–`.010`)
1. What did your childhood kitchen smell like, and who was cooking?
2. Walk us down the street where you grew up. What do we see?
3. What is a time you got in trouble as a kid, and what happened?
4. Which grown-up could always make you laugh when you were little, and how?
5. What was your first real job, and what happened there?
6. What did a Saturday night out look like when you were young?
7. What was the day you first left home like?
8. What did your own grandparents tell you that you still remember?
9. What was the hardest year you lived through, and what got you through it?
10. What from your childhood would kids today never believe?

### Parents (`parents.001`–`.010`)
1. What do you remember about the day I was born?
2. What did you think being a parent would be like, and what surprised you?
3. What were the nights like when I was a baby?
4. What song, show, or game takes you straight back to when we were little?
5. What is a family rule you made up on the spot?
6. What is a mistake you made as a parent that turned out fine?
7. What was your first place on your own like?
8. What did you and your parents argue about when you were my age?
9. What did raising us teach you that you didn't expect?
10. What is one thing we do as a family that you hope we always do?

### Kids Ask the Grownups (`kids.001`–`.010`)
1. What was your favorite toy, and where is it now?
2. What did your house look like when you were a kid?
3. Who was your best friend, and what did you two do?
4. What food did you hate when you were little, and what happened?
5. What is the silliest thing you ever did at school?
6. What rule did you break when you were little?
7. What job did you want when you were little, and why?
8. What were you scared of when you were my age?
9. What present do you still remember, and why?
10. What day from when you were little would you want to do over?

### Couples (`couples.001`–`.010`)
1. Take us back to the first time you two met. What do you see?
2. What did you notice first about each other?
3. What happened on your first real date?
4. What moment told you this was going to be serious?
5. What was your first home together like?
6. What is a trip or adventure you two still talk about?
7. What does one of you do that still makes the other laugh?
8. What does an ordinary morning together look like?
9. What was a hard stretch you got through together, and how?
10. What small moment shows what your life together is really like?

### Holiday Table (`holiday-table.001`–`.010`, round-robin)
1. What is a dish that makes it feel like a holiday to you?
2. What did holidays feel like when you were small?
3. What is the funniest thing that ever happened at a family gathering?
4. What is a tradition you'd never let us skip?
5. What gift do you still remember giving or getting?
6. What is a holiday that went wrong but became a good story?
7. What is a family story that gets told every year?
8. What is a holiday you remember better than any other, and why?
9. What is one good thing from this year you want to remember?
10. What is one thing you hope we're all doing a year from now?

## 3. Code — `StoryCue/Decks.swift`, `StoryCue/Deck.swift`

- `Decks.swift`: replace each deck's `(1...10).map { ... "// TODO copy" ... }` with an explicit
  list built by one private helper, so the IDs stay generated and the text is a literal array:

  ```swift
  private static func questions(_ deckID: String, _ texts: [String]) -> [Question] {
      texts.enumerated().map { i, text in
          Question(id: String(format: "\(deckID).%03d", i + 1), text: text, isVHPSourced: false)
      }
  }
  ```

  and each deck uses `questions: questions("grandparents", [ ... 10 string literals ... ])`.
  The helper sits in the same `extension Deck`. String literals are exactly section 2's text.
- `Decks.swift` doc comment becomes: `/// The five v1 decks from PLAN §2. All included in v1
  (SYNTHESIS Q7: free, all decks included). Question copy is S4 (docs/S4-DECK-COPY-SPEC.md);
  DeckDataTests lints it.`
- `Deck.swift` line 7 comment becomes `// original copy, docs/S4-DECK-COPY-SPEC.md`.

## 4. Tests — append to `StoryCueTests/DeckDataTests.swift`

Six tests. Assert on `Deck.v1Decks` directly (no source-file scan). Each failure message names the
question ID.

| Test | Asserts |
|---|---|
| `testNoV1QuestionIsPlaceholder` | no `text` contains `TODO`; every `text` is non-empty and equal to itself trimmed of whitespace/newlines |
| `testEveryV1QuestionEndsWithQuestionMark` | `text.hasSuffix("?")` |
| `testEveryV1QuestionFitsTheOuterDisplay` | word count (split on whitespace) `<= 15` and `text.count <= 80` |
| `testNoV1QuestionOpensAsYesNo` | the first word (letters and apostrophes only, lowercased) is not in `["did", "do", "does", "have", "has", "is", "are", "was", "were", "can", "could", "would", "will", "should", "am", "had", "don't", "doesn't", "didn't", "isn't", "aren't", "wasn't", "weren't", "won't", "wouldn't", "hasn't", "haven't"]` |
| `testV1QuestionTextIsUniqueAcrossDecks` | `Set(texts).count == texts.count` over all 50 |
| `testEveryV1QuestionIsPlainASCII` | `text.unicodeScalars.allSatisfy(\.isASCII)` |

Existing tests stay unchanged (count 8–12, IDs unique, modes, `isIncluded`, no VHP).

## 5. Done when

PR CI green on both lanes (baseline + Duo flag), test count 166 → 172, `grep -rn "TODO copy"
StoryCue/` returns nothing (the one in `ExportPlannerTests.swift` is a test fixture and stays).

## 6. Review and adjudication

**Kimi was unavailable** (2026-09-30: `403 access_terminated_error`, weekly cap), so the
readability pass was a fresh-context **Sonnet** review of this spec (the copy was inline).
Its findings, adjudicated:

- **Accepted, copy (17 lines changed):** grandparents .002 (awkward "pass"), .003 / .007 and
  kids .004 / .009, couples .003 (invite one-word answers), grandparents .006 ("twenty" is a
  number), .010 and couples .010 (abstract, not a story; nearest to StoryCorps "remembered" /
  "advice for couples" territory), kids .010 (abstract for a 7-year-old), parents .003 / .009 /
  .010 (awkward aloud; .009 read as guilt; .010 overlapped holiday-table .004), couples .007 /
  .008 (near-duplicates, third-person "your partner"), holiday-table .002 (child at the table
  can't answer "house you grew up in"), .008 (newcomers-only; reworded by Opus rather than the
  suggested "at this house", which assumes the venue).
- **Accepted, spec:** rule 3 said "≤ 3 lines" but 15 words at 4 a line is 4 lines, now "3–4
  lines" (the cap stays 15; the longest question is exactly 15 words, 73 characters is the longest); a plain-ASCII test (sixth test);
  a longer yes/no opener list.
- **Noted, no change:** couples .004 is the closest topic to "how did you know they were the
  one"; the wording is original. Exact-match uniqueness can't catch topic overlap and rules 5–6
  aren't machine-checkable; this review is their gate.
- **Rejected:** "dangling doc reference" -- a misread; the spec lives at
  `docs/S4-DECK-COPY-SPEC.md` (the reviewer saw a scratch copy).
