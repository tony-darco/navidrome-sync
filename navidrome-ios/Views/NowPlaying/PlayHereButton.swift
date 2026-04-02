import SwiftUI

struct PlayHereButton: View {
    @EnvironmentObject private var store: SyncStore

    var body: some View {
        if store.myRole != "active", let song = store.nowPlaying {
            Button {
                store.playSong(song)
            } label: {
                Label("Play Here", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .clipShape(Capsule())
            }
        }
    }
}
