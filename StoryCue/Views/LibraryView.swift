import SwiftUI

/// The recordings list: recovered clips awaiting a keep/delete decision, then one row per
/// session. Every delete asks first; there is no `.onDelete`, because a full swipe would skip
/// the confirmation.
struct LibraryView: View {
    let model: AppModel

    @State private var pendingSessionDelete: UUID?
    @State private var pendingClipDelete: RecoveredClip?

    private var library: Library { model.library }

    var body: some View {
        let recovered = library.recovered
        return List {
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
            if library.sessions.isEmpty && recovered.isEmpty {
                ContentUnavailableView(
                    UICopy.libraryEmptyTitle,
                    systemImage: "video.slash",
                    description: Text(UICopy.libraryEmptyBody)
                )
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
                Task { await library.delete(sessionID: sessionID) }
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
        .padding(.vertical, 4)
    }

    private func sessionRow(_ record: SessionRecord) -> some View {
        NavigationLink {
            SessionDetailView(sessionID: record.id, model: model)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.deckTitle)
                    .font(.title2)
                Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(UICopy.clipCount(record.manifest.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if library.canDelete(record.id) {
                Button(UICopy.deleteSession, role: .destructive) {
                    pendingSessionDelete = record.id
                }
            }
        }
    }
}
