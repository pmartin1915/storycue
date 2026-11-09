import SwiftUI

/// The app's haptic vocabulary: one name per meaning, so the same event always feels the same
/// (HOUSE-STYLE rule 10: every haptic has a visible twin). Views use these names, never a
/// literal `SensoryFeedback`; StyleLintTests enforces that. iOS silences haptics while the
/// camera is recording, so none of these can reach a take.
enum Haptics {
    /// Recording starts or pauses (the record glyph morphs).
    static let recordToggle = SensoryFeedback.impact(weight: .medium)
    /// The question changes, or the question card is set down.
    static let step = SensoryFeedback.selection
    /// Work finished: a recording saved, an export done.
    static let success = SensoryFeedback.success
    /// Work failed: an export did not finish.
    static let failure = SensoryFeedback.error
}
