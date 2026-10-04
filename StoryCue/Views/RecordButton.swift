import SwiftUI

struct RecordButton: View {
    let primary: RecorderPresentation.Primary
    let label: String
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(DesignTokens.overCameraFill)
                    Circle()
                        .strokeBorder(.white, lineWidth: DesignTokens.RecordButton.ringWidth)

                    switch primary.glyph {
                    case .dot, .square:
                        let isSquare = primary.glyph == .square
                        RoundedRectangle(
                            cornerRadius: isSquare
                                ? DesignTokens.RecordButton.squareRadius
                                : DesignTokens.RecordButton.dot / 2
                        )
                        .fill(Color.red)
                        .frame(
                            width: isSquare
                                ? DesignTokens.RecordButton.square
                                : DesignTokens.RecordButton.dot,
                            height: isSquare
                                ? DesignTokens.RecordButton.square
                                : DesignTokens.RecordButton.dot
                        )
                        .animation(
                            reduceMotion ? nil : DesignTokens.Motion.morph,
                            value: primary.glyph
                        )
                    case .spinner:
                        ProgressView()
                            .tint(.white)
                    case .cancel:
                        Circle()
                            .fill(DesignTokens.overCameraFill)
                            .frame(
                                width: DesignTokens.RecordButton.dot,
                                height: DesignTokens.RecordButton.dot
                            )
                        Image(systemName: "xmark")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                }
                .frame(
                    width: DesignTokens.RecordButton.outer,
                    height: DesignTokens.RecordButton.outer
                )
                .contentShape(Circle())
            }
            .disabled(primary == .saving || primary == .unavailable)
            .accessibilityLabel(label)
            .accessibilityIdentifier("recordButton")

            Text(label)
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(.horizontal, DesignTokens.Spacing.s)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(DesignTokens.overCameraFill, in: Capsule())
                .accessibilityHidden(true)
        }
    }
}
