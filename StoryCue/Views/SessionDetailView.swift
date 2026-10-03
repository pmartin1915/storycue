import SwiftUI

/// One recording: its answers in order, Keep/Delete for undecided recovered clips, Export,
/// and Delete recording. Reads the record live: it may be deleted out from under this view.
struct SessionDetailView: View {
    let sessionID: UUID
    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @State private var exportModel: ExportModel?
    @State private var showDeleteSessionConfirm = false
    @State private var pendingClipDelete: RecoveredClip?

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
    }

    private var canExportNow: Bool {
        ExportModel(sessionID: sessionID, library: library, exporter: model.exporter).canExport
    }

    private func clipRow(_ clip: Clip, record: SessionRecord, isActive: Bool) -> some View {
        let position = record.questionPosition(for: clip.questionID)
        let hasKeptFailure = clip.segments.contains { $0.outcome == .failed(kept: true) }
        let undecided = clip.segments.filter { $0.outcome == nil }
        return VStack(alignment: .leading, spacing: 8) {
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
