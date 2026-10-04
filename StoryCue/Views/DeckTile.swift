import SwiftUI

struct DeckTile: View {
    let deckID: String

    @ScaledMetric(relativeTo: .title2) private var side: CGFloat = 48

    var body: some View {
        let cappedSide = min(side, 72)
        Image(systemName: DesignTokens.deckSymbol(deckID))
            .font(.title2)
            .foregroundStyle(DesignTokens.tileSymbol)
            .frame(width: cappedSide, height: cappedSide)
            .background(
                DesignTokens.tileFill,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.tile)
            )
            .accessibilityHidden(true)
    }
}

struct DeckRowLabel<Detail: View>: View {
    let deckID: String
    let title: String
    @ViewBuilder let detail: Detail

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.m) {
                    DeckTile(deckID: deckID)
                    text
                }
            } else {
                HStack(spacing: DesignTokens.Spacing.m) {
                    DeckTile(deckID: deckID)
                    text
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var text: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title2)
            detail
        }
    }
}
