import SwiftUI

/// The recordings list: recovered clips awaiting a keep/delete decision, then one row per
/// session. Every delete asks first; there is no `.onDelete`, because a full swipe would skip
/// the confirmation.
struct LibraryView: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @State private var pendingSessionDelete: UUID?
    @State private var pendingClipDelete: RecoveredClip?

    private var library: Library { model.library }

    var body: some View {
        let recovered = library.recovered
        return List {
            if !library.isLoaded {
                // Placeholder rows in the shape of real ones until the library has loaded.
                Section {
                    ForEach(0..<3, id: \.self) { _ in
                        DeckRowLabel(deckID: "", title: UICopy.libraryTitle) {
                            Text(UICopy.sessionSubtitle(.now, count: 3))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .redacted(reason: .placeholder)
                .accessibilityHidden(true)
            }
            if !recovered.isEmpty {
                Section {
                    ForEach(recovered) { clip in
                        recoveredRow(clip)
                    }
                } header: {
                    Text(UICopy.recoveredHeader)
                } footer: {
                    Text(UICopy.recoveredExplainer)
                }
            }

            if !library.sessions.isEmpty {
                Section {
                    ForEach(library.sessions) { record in
                        sessionRow(record)
                    }
                }
            }

            Section {
            } footer: {
                Text(UICopy.storageFooter(
                    used: library.storage.usedBytes,
                    available: library.storage.availableBytes
                ))
            }
        }
        .overlay {
            if library.isLoaded && library.sessions.isEmpty && recovered.isEmpty {
                ContentUnavailableView {
                    Label(UICopy.libraryEmptyTitle, systemImage: "video.slash")
                } description: {
                    Text(UICopy.libraryEmptyBody)
                } actions: {
                    Button(UICopy.libraryEmptyAction) { dismiss() }
                        .primaryAction()
                }
            }
        }
        .navigationTitle(UICopy.libraryTitle)
        .onAppear { library.refreshStorage() }
        .confirmationDialog(
            UICopy.deleteSessionConfirm,
            isPresented: Binding(
                get: { pendingSessionDelete != nil },
                set: { isPresented in
                    if !isPresented { pendingSessionDelete = nil }
                }
            ),
            titleVisibility: .visible,
            presenting: pendingSessionDelete
        ) { sessionID in
            Button(UICopy.deleteSession, role: .destructive) {
                Task {
                    if await library.delete(sessionID: sessionID) {
                        model.showToast(UICopy.recordingDeleted)
                    }
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
                Task {
                    await library.discard(clip)
                    if library.isDecided(clip) { model.showToast(UICopy.answerDeleted) }
                }
            }
        }
    }

    private func recoveredRow(_ clip: RecoveredClip) -> some View {
        let record = library.record(id: clip.sessionID)
        let counter: String
        if let position = record?.questionPosition(for: clip.segment.questionID) {
            counter = UICopy.questionCounter(position.index, position.count)
        } else {
            counter = clip.segment.questionID
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text(record?.deckTitle ?? "")
                .font(.title2)
            Text(counter)
                .font(.body)
            Text(clip.segment.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.callout)
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Button(UICopy.keep) {
                    Task {
                        await library.keep(clip)
                        if library.isDecided(clip) { model.showToast(UICopy.answerKept) }
                    }
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
        .padding(.vertical, 4)
    }

    private func sessionRow(_ record: SessionRecord) -> some View {
        NavigationLink {
            SessionDetailView(sessionID: record.id, model: model)
        } label: {
            DeckRowLabel(deckID: record.deckID, title: record.deckTitle) {
                Text(UICopy.sessionSubtitle(record.startedAt, count: record.manifest.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("session.\(record.deckID)")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if library.canDelete(record.id) {
                Button(UICopy.deleteSession, role: .destructive) {
                    pendingSessionDelete = record.id
                }
            }
        }
    }
}
