import Foundation

extension Deck {
    /// The five v1 decks from PLAN §2. All included in v1 (SYNTHESIS Q7: free, all decks
    /// included). Question copy is S4 (docs/S4-DECK-COPY-SPEC.md); DeckDataTests lints it.
    static let v1Decks: [Deck] = [
        Deck(
            id: "grandparents",
            title: "Grandparents",
            mode: .sequential,
            questions: questions("grandparents", [
                "What did your childhood kitchen smell like, and who was cooking?",
                "Walk us down the street where you grew up. What do we see?",
                "What is a time you got in trouble as a kid, and what happened?",
                "Which grown-up could always make you laugh when you were little, and how?",
                "What was your first real job, and what happened there?",
                "What did a Saturday night out look like when you were young?",
                "What was the day you first left home like?",
                "What did your own grandparents tell you that you still remember?",
                "What was the hardest year you lived through, and what got you through it?",
                "What from your childhood would kids today never believe?",
            ]),
            isIncluded: true
        ),
        Deck(
            id: "parents",
            title: "Parents",
            mode: .sequential,
            questions: questions("parents", [
                "What do you remember about the day I was born?",
                "What did you think being a parent would be like, and what surprised you?",
                "What were the nights like when I was a baby?",
                "What song, show, or game takes you straight back to when we were little?",
                "What is a family rule you made up on the spot?",
                "What is a mistake you made as a parent that turned out fine?",
                "What was your first place on your own like?",
                "What did you and your parents argue about when you were my age?",
                "What did raising us teach you that you didn't expect?",
                "What is one thing we do as a family that you hope we always do?",
            ]),
            isIncluded: true
        ),
        Deck(
            id: "kids",
            title: "Kids Ask the Grownups",
            mode: .sequential,
            questions: questions("kids", [
                "What was your favorite toy, and where is it now?",
                "What did your house look like when you were a kid?",
                "Who was your best friend, and what did you two do?",
                "What food did you hate when you were little, and what happened?",
                "What is the silliest thing you ever did at school?",
                "What rule did you break when you were little?",
                "What job did you want when you were little, and why?",
                "What were you scared of when you were my age?",
                "What present do you still remember, and why?",
                "What day from when you were little would you want to do over?",
            ]),
            isIncluded: true
        ),
        Deck(
            id: "couples",
            title: "Couples",
            mode: .sequential,
            questions: questions("couples", [
                "Take us back to the first time you two met. What do you see?",
                "What did you notice first about each other?",
                "What happened on your first real date?",
                "What moment told you this was going to be serious?",
                "What was your first home together like?",
                "What is a trip or adventure you two still talk about?",
                "What does one of you do that still makes the other laugh?",
                "What does an ordinary morning together look like?",
                "What was a hard stretch you got through together, and how?",
                "What small moment shows what your life together is really like?",
            ]),
            isIncluded: true
        ),
        Deck(
            id: "holiday-table",
            title: "Holiday Table",
            mode: .roundRobin,
            questions: questions("holiday-table", [
                "What is a dish that makes it feel like a holiday to you?",
                "What did holidays feel like when you were small?",
                "What is the funniest thing that ever happened at a family gathering?",
                "What is a tradition you'd never let us skip?",
                "What gift do you still remember giving or getting?",
                "What is a holiday that went wrong but became a good story?",
                "What is a family story that gets told every year?",
                "What is a holiday you remember better than any other, and why?",
                "What is one good thing from this year you want to remember?",
                "What is one thing you hope we're all doing a year from now?",
            ]),
            isIncluded: true
        ),
    ]

    private static func questions(_ deckID: String, _ texts: [String]) -> [Question] {
        texts.enumerated().map { i, text in
            Question(id: String(format: "\(deckID).%03d", i + 1), text: text, isVHPSourced: false)
        }
    }
}
