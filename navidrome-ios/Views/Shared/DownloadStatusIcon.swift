import SwiftUI

/// Displays download status for a song: pending, downloading (progress ring), completed, or failed.
struct DownloadStatusIcon: View {
    let task: DownloadTask?

    var body: some View {
        if let task {
            switch task.status {
            case .pending:
                Image(systemName: "arrow.down.circle.dotted")
                    .font(.body)
                    .foregroundStyle(.secondary)

            case .downloading(let progress):
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.brandPink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 18, height: 18)

            case .paused:
                Image(systemName: "pause.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)

            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.green)

            case .failed:
                Image(systemName: "exclamationmark.circle")
                    .font(.body)
                    .foregroundStyle(.red)
            }
        }
    }
}
