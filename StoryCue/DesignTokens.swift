import SwiftUI

enum DesignTokens {
    enum Spacing {           // multiples of 4
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }
    enum Radius {
        static let card: CGFloat = 12      // cards, banners, callouts
        static let tile: CGFloat = 10      // deck tiles
    }
    enum Motion {                          // nothing over 0.5 s
        static let morph = Animation.spring(duration: 0.3)
        static let fade = Animation.easeOut(duration: 0.2)
    }
    enum RecordButton {
        static let outer: CGFloat = 72
        static let ringWidth: CGFloat = 4
        static let dot: CGFloat = 58
        static let square: CGFloat = 28
        static let squareRadius: CGFloat = 6
    }
    /// The serif trial (design review row 6). Revert to `.default` in this one line.
    static let questionFontDesign: Font.Design = .serif
    static let onAccent = Color("OnAccent")
    /// Deck tiles: one terracotta family, never a rainbow (WW-0103 disagreement 4).
    static let tileFill = Color.accentColor.opacity(0.15)
    static let tileSymbol = Color.accentColor
    static func deckSymbol(_ deckID: String) -> String {
        switch deckID {
        case "grandparents": "house"
        case "parents": "figure.2.and.child.holdinghands"
        case "kids": "questionmark.bubble"
        case "couples": "heart"
        case "holiday-table": "fork.knife"
        default: "text.bubble"
        }
    }
    /// Translucent black behind text over the camera (≥ 7:1 white text over a white feed).
    static let overCameraFill = Color.black.opacity(0.7)
    /// The recording pill: darker than system red so white text clears 4.5:1.
    static let recordingFill = Color(red: 0.78, green: 0.10, blue: 0.10)
    #if DEBUG
    static let demoBackdropTop = Color(red: 0.20, green: 0.13, blue: 0.09)
    static let demoBackdropBottom = Color(red: 0.06, green: 0.04, blue: 0.03)
    #endif
}

extension View {
    /// The one filled primary action of a screen: full width, large, accent fill,
    /// `OnAccent` label. Apply to a `Button` whose label is `Text`.
    func primaryAction() -> some View {
        self
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .foregroundStyle(DesignTokens.onAccent)
    }
}
