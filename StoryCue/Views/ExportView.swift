import SwiftUI

/// The export sheet over `ExportModel`. It can't be swiped away mid-export, and leaving it
/// cancels a running export or closes a pending share (so the temp directory and the
/// exporting flag never outlive the sheet).
struct ExportView: View {
    @Bindable var model: ExportModel
    @Environment(\.dismiss) private var dismiss

    private var isRunning: Bool {
        if case .running = model.phase { return true }
        return false
    }

    private var sharingResult: ExportResult? {
        if case let .sharing(result) = model.phase { return result }
        return nil
    }

    var body: some View {
        NavigationStack {
            content
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .navigationTitle(UICopy.exportTitle)
                .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(isRunning)
        .onDisappear {
            switch model.phase {
            case .running:
                model.cancel()
            case .sharing:
                Task { await model.shareDismissed() }
            case .choosing, .finished, .failed:
                break
            }
        }
        .sheet(
            isPresented: Binding(
                get: { sharingResult != nil },
                set: { isPresented in
                    if !isPresented { Task { await model.shareDismissed() } }
                }
            )
        ) {
            if let result = sharingResult {
                shareSheet(for: result)
            }
        }
    }

    private func shareSheet(for result: ExportResult) -> some View {
        let model = self.model
        return ShareSheet(items: result.files) {
            Task { await model.shareDismissed() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .choosing:
            choosing
        case let .running(done, total):
            running(done: done, total: total)
        case .sharing:
            // The share sheet is up; this is what shows behind it.
            Text(UICopy.exporting(0, 0))
                .font(.body)
        case let .finished(message), let .failed(message):
            VStack(alignment: .leading, spacing: 20) {
                Text(message)
                    .font(.body)
                Button(UICopy.done) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .font(.title2)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    private var choosing: some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker(UICopy.exportTitle, selection: $model.unit) {
                Text(UICopy.exportEachAnswer).tag(ExportUnit.perClip)
                Text(UICopy.exportOneVideo).tag(ExportUnit.wholeSession)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Button(UICopy.exportToFiles) { model.start(.files) }
                .buttonStyle(.borderedProminent)
                .font(.title2)
                .frame(maxWidth: .infinity, minHeight: 44)

            Button(UICopy.exportToPhotos) { model.start(.photos) }
                .buttonStyle(.bordered)
                .font(.title2)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func running(done: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if total == 0 {
                ProgressView()
            } else {
                ProgressView(value: Double(done), total: Double(total))
            }
            Text(UICopy.exporting(done, total))
                .font(.body)
            Button(UICopy.cancel) { model.cancel() }
                .buttonStyle(.bordered)
                .font(.title2)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }
}
