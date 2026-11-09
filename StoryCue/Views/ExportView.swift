import SwiftUI

/// The export sheet over `ExportModel`. It can't be swiped away mid-export, and leaving it
/// cancels a running export or closes a pending share (so the temp directory and the
/// exporting flag never outlive the sheet).
struct ExportView: View {
    @Bindable var model: ExportModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            // Scrolls so long result/failure copy at accessibility sizes can't push Done off screen.
            ScrollView {
                content
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle(UICopy.exportTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(isRunning)
        // The export can run long with the phone held away; a distinct tap says how it ended.
        .sensoryFeedback(trigger: model.phase) { _, new in
            switch new {
            case .finished: Haptics.success
            case .failed: Haptics.failure
            case .choosing, .running, .sharing: nil
            }
        }
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
        case let .finished(message):
            outcome(message, isFailure: false)
        case let .failed(message):
            outcome(message, isFailure: true)
        }
    }

    /// Success and failure look different (symbol, not color alone) and failure offers a retry.
    private func outcome(_ message: String, isFailure: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.m) {
                Image(systemName: isFailure ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isFailure ? Color.orange : Color.accentColor)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.body)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(isFailure ? "exportFailed" : "exportFinished")
            if isFailure {
                Button {
                    model.retry()
                } label: {
                    Text(UICopy.tryAgain)
                        .frame(maxWidth: .infinity)
                }
                .primaryAction()
                .accessibilityIdentifier("exportTryAgain")
                Button {
                    dismiss()
                } label: {
                    Text(UICopy.done)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            } else {
                Button {
                    dismiss()
                } label: {
                    Text(UICopy.done)
                        .frame(maxWidth: .infinity)
                }
                .primaryAction()
            }
        }
    }

    private var choosing: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            // Segments can't wrap, so at accessibility sizes the choice becomes a menu button.
            if dynamicTypeSize.isAccessibilitySize {
                unitPicker
                    .pickerStyle(.menu)
                    .frame(minHeight: 44)
            } else {
                unitPicker
                    .pickerStyle(.segmented)
                    .frame(minHeight: 44)
            }

            Button {
                model.start(.files)
            } label: {
                Text(UICopy.exportToFiles)
                    .frame(maxWidth: .infinity)
            }
            .primaryAction()

            Button {
                model.start(.photos)
            } label: {
                Text(UICopy.exportToPhotos)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var unitPicker: some View {
        Picker(UICopy.exportTitle, selection: $model.unit) {
            Text(UICopy.exportEachAnswer).tag(ExportUnit.perClip)
            Text(UICopy.exportOneVideo).tag(ExportUnit.wholeSession)
        }
        .labelsHidden()
    }

    private func running(done: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            if total == 0 {
                ProgressView()
            } else {
                ProgressView(value: Double(done), total: Double(total))
            }
            Text(UICopy.exporting(done, total))
                .font(.body)
            Button {
                model.cancel()
            } label: {
                Text(UICopy.cancel)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}
