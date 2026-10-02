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

    // MARK: - S2b: library, recovery, delete, export

    /// Human-readable file size (`ByteCountFormatter`, `.file` style).
    static func fileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    static let unknownQuestion = "A question"

    static let libraryButton = "Recordings"
    static let libraryTitle = "Recordings"
    static let libraryEmptyTitle = "No recordings yet"
    static let libraryEmptyBody = "Choose a deck to record your first conversation."
    static func clipCount(_ n: Int) -> String { n == 1 ? "1 answer" : "\(n) answers" }

    static func storageFooter(used: Int64, available: Int64?) -> String {
        var text = "Recordings use \(fileSize(used))."
        if let available {
            text += " \(fileSize(available)) free on this iPhone."
        }
        return text
    }

    static func lowSpaceBanner(_ available: Int64?) -> String {
        if let available {
            return "Your iPhone is almost full (\(fileSize(available)) free). Long answers may not fit."
        }
        return "Your iPhone is almost full. Long answers may not fit."
    }
    static let lowSpaceConsentNote = "Your iPhone is low on space. Free some up before a long conversation."

    static let recoveredHeader = "Recovered clips"
    static let recoveredExplainer = "StoryCue closed while these were recording. They may end early. Keep them or delete them."
    static let recoveredUndecided = "Recovered after StoryCue closed. It may end early."
    static let keep = "Keep"
    static let deleteClip = "Delete clip"
    static let deleteClipConfirm = "Delete this clip? This can't be undone."
    static let deleteSession = "Delete recording"
    static let deleteSessionConfirm = "Delete this whole recording? This can't be undone."
    static let sessionGone = "This recording was deleted."
    static let mayBeIncomplete = "Part of this answer may be incomplete."

    static let export = "Export"
    static let exportTitle = "Export"
    static let exportEachAnswer = "Each answer"
    static let exportOneVideo = "One video"
    static let exportToFiles = "Save or share…"
    static let exportToPhotos = "Save to Photos"
    static func exporting(_ done: Int, _ total: Int) -> String {
        total == 0 ? "Preparing…" : "Exporting \(done) of \(total)…"
    }
    static func exportDone(destination: ExportDestination, count: Int) -> String {
        switch destination {
        case .photos:
            return count == 1 ? "Saved 1 video to Photos." : "Saved \(count) videos to Photos."
        case .files:
            return count == 1 ? "Exported 1 video." : "Exported \(count) videos."
        }
    }
    static func droppedNote(_ n: Int) -> String {
        n == 1 ? "1 part couldn't be read and was left out." : "\(n) parts couldn't be read and were left out."
    }
    static let flaggedNote = "Part of this export may be incomplete."
}
