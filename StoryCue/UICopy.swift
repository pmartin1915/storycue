import Foundation

/// Every user-visible string in S2a lives here (a `static let`, or a `static func` for
/// the two parameterised ones), so the S4 copy review and the S6 privacy-policy check
/// have one file to read. No string literal shown to the user outside this file.
enum UICopy {
    static let appTitle = "StoryCue"
    static let deckPickerTitle = "Choose a deck"
    static func questionCount(_ n: Int) -> String { "\(n) questions" }

    // Consent card (also the permission-priming screen: the system camera/mic prompts
    // appear only after the confirm tap, with this explanation already on screen).
    static let consentTitle = "Before you start"
    static let consentBody = "Everyone on camera needs to agree to be recorded. When you start, have the person you're interviewing read this line aloud:"
    static let readAloudLine = "I understand this is being recorded, and I am ready to begin."
    /// The read-aloud line as the consent card shows it, in curly quotes.
    static var readAloudCallout: String { "\u{201C}\(readAloudLine)\u{201D}" }
    static let privacyNote = "Recordings stay on this phone. Nothing is uploaded."
    static let consentConfirm = "We're ready"

    static func questionCounter(_ i: Int, _ n: Int) -> String { "Question \(i + 1) of \(n)" }

    static let record = "Record"
    static let pause = "Pause"
    static let resume = "Resume"
    static let saving = "Saving…"
    static let cancel = "Cancel"

    static let skip = "Skip"
    static let next = "Next question"
    static let finish = "Finish"
    static let done = "Done"

    static let readAloudBanner = "Start by reading the consent line aloud."
    static let noAudioBanner = "No microphone. Video will record without sound."

    static let preparing = "Starting the camera…"
    static let notAuthorizedTitle = "Camera or microphone is off"
    static let notAuthorizedBody = "Turn on Camera and Microphone for StoryCue in Settings to record."
    static let openSettings = "Open Settings"
    static let unavailableTitle = "Camera unavailable"
    static let unavailableBody = "StoryCue can't use the camera right now. Close other camera apps and try again."

    static func pausedBanner(_ reason: SegmentEndReason) -> String {
        switch reason {
        case .segmentCapReached:
            return "Ten minutes on this answer. Keep going?"
        case .audioInterruption:
            return "Paused for a call or other audio."
        case .captureInterruption:
            return "The camera was interrupted."
        case .sceneResignedActive, .sceneBackgrounded:
            return "Paused when StoryCue left the screen."
        case .thermalShutdown:
            return "Paused so the phone can cool down."
        case .runtimeError, .mediaServicesReset, .outputEndedUnexpectedly:
            return "Recording stopped unexpectedly. What was recorded is kept."
        case .directionChanged, .hingeClosed, .accessoryWithdrawn:
            // Duo reasons — unreachable in 1.0, but the switch stays exhaustive so a new
            // reason is a compile error here.
            return "Paused when the camera changed."
        case .userPause, .userStop:
            return ""   // never shown
        }
    }
}
