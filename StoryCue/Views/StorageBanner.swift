import SwiftUI

/// Low-space warning. No button: it informs, it never blocks recording.
struct StorageBanner: View {
    let availableBytes: Int64?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(UICopy.lowSpaceBanner(availableBytes))
                .font(.callout)
        }
        .padding(.vertical, 4)
    }
}
