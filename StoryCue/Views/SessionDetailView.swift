import SwiftUI

/// One recording: its answers in order, Keep/Delete for undecided recovered clips, Export,
/// and Delete recording. Reads the record live: it may be deleted out from under this view.
struct SessionDetailView: View {
    let sessionID: UUID
    let model: AppModel
    /// True when this screen was opened by "Done" right after recording (S2c): shows the
    /// one-line completion header and fires a one-time success haptic.
    var showsCompletion: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var exportModel: ExportModel?
    @State private var showDeleteSessionConfirm = false
    @State private var pendingClipDelete: RecoveredClip?
    @State private var playing: PlayableAnswer?
    @State private var didAppear = false

    private var library: Library { model.library }

    var body: some View {
        Group {
            if let record = library.record(id: sessionID) {
                content(record)
            } else {
                Text(UICopy.sessionGone)
                    .font(.body)
                    .padding()
            }
        }
        .navigationTitle(library.record(id: sessionID)?.deckTitle ?? UICopy.libraryTitle)
        .navigationBarTitleDisplayMode(.inline)
        // Only the post-recording screen celebrates; opening a session from Recordings doesn't.
        .onAppear { if showsCompletion { didAppear = true } }
        .sensoryFeedback(.success, trigger: didAppear)
    }

    private func isShown(_ clip: Clip) -> Bool {
        clip.segments.contains { $0.outcome != .failed(kept: false) }
    }

    private func content(_ record: SessionRecord) -> some View {
        let isActive = sessionID == library.activeSessionID
        let shownClips = record.clips.filter { isShown($0) }
        return List {
            Section {
                ForEach(shownClips, id: \.questionID) { clip in
                    clipRow(clip, record: record, isActive: isActive)
                }
            } header: {
                if showsCompletion, record.manifest.count > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(UICopy.completionTitle(record.manifest.count))
                            .font(.title3.bold())
                        Text(UICopy.completionBody)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .textCase(nil)   // inset-grouped headers uppercase by default
                    .foregroundStyle(.primary)
                }
            }
            Section {
                Button(UICopy.deleteSession, role: .destructive) {
                    showDeleteSessionConfirm = true
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(!library.canDelete(sessionID))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(UICopy.export) {
                    exportModel = ExportModel(
                        sessionID: sessionID,
                        library: library,
                        exporter: model.exporter
                    )
                }
                .disabled(!canExportNow)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { exportModel != nil },
                set: { isPresented in
                    if !isPresented { exportModel = nil }
                }
            )
        ) {
            if let exportModel {
                ExportView(model: exportModel)
            }
        }
        .confirmationDialog(
            UICopy.deleteSessionConfirm,
            isPresented: $showDeleteSessionConfirm,
            titleVisibility: .visible
        ) {
            Button(UICopy.deleteSession, role: .destructive) {
                Task {
                    let deleted = await library.delete(sessionID: sessionID)
                    if deleted { dismiss() }
                }
            }
        }
        .confirmationDialog(
            UICopy.deleteClipConfirm,
            isPresented: Binding(
                get: { pendingClipDelete != nil },
                set: { isPresented in
                    if !isPresented { pendingClipDelete = nil }
                }
            ),
            titleVisibility: .visible,
            presenting: pendingClipDelete
        ) { clip in
            Button(UICopy.deleteClip, role: .destructive) {
                Task { await library.discard(clip) }
            }
        }
        .fullScreenCover(item: $playing) { answer in
            AnswerPlayerView(
                sources: playbackSources(for: record, questionID: answer.questionID, in: model.segmentDirectory),
                caption: record.questionPosition(for: answer.questionID)?.text ?? UICopy.unknownQuestion
            )
        }
    }

    private var canExportNow: Bool {
        ExportModel(sessionID: sessionID, library: library, exporter: model.exporter).canExport
    }

    private func clipRow(_ clip: Clip, record: SessionRecord, isActive: Bool) -> some View {
        let position = record.questionPosition(for: clip.questionID)
        let hasKeptFailure = clip.segments.contains { $0.outcome == .failed(kept: true) }
        let undecided = clip.segments.filter { $0.outcome == nil }
        // The camera owns the audio session while its session is active, so a still-open
        // session's rows get no play button. Sources come from the export manifest rules.
        let sources = playbackSources(for: record, questionID: clip.questionID, in: model.segmentDirectory)
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                if let position {
                    Text(UICopy.questionCounter(position.index, position.count))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(position.text)
                        .font(.body)
                } else {
                    Text(UICopy.unknownQuestion)
                        .font(.body)
                }
                if hasKeptFailure {
                    Text(UICopy.mayBeIncomplete)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !isActive {
                    ForEach(undecided, id: \.id) { segment in
                        undecidedControls(RecoveredClip(sessionID: sessionID, segment: segment))
                    }
                }
            }
            if !sources.isEmpty && !isActive {
                Button {
                    playing = PlayableAnswer(questionID: clip.questionID)
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(UICopy.playAnswer)
            }
        }
        .padding(.vertical, 4)
    }

    private func undecidedControls(_ clip: RecoveredClip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UICopy.recoveredUndecided)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(UICopy.keep) {
                Task { await library.keep(clip) }
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, minHeight: 44)
            Button(UICopy.deleteClip, role: .destructive) {
                pendingClipDelete = clip
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }
}
