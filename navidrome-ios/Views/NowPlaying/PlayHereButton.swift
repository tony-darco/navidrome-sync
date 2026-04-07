import SwiftUI

struct PlayHereButton: View {
    @EnvironmentObject private var store: SyncStore

    var body: some View {
        if store.myRole != "active" {
            Button {
                store.claim()
            } label: {
                Label("Play Here", systemImage: "play.fill")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.brandPink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandPink.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
    }
}
