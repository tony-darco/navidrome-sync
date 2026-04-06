import SwiftUI

struct PlaylistCreateSheet: View {
    @EnvironmentObject private var playlistStore: PlaylistStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Playlist name", text: $name)
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        isSaving = true
                        Task {
                            await playlistStore.createPlaylist(name: name.trimmingCharacters(in: .whitespaces))
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
