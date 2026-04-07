import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SyncStore
    @Binding var isLoggedIn: Bool
    @State private var syncURL: String = AppConfig.syncServiceURL ?? ""
    @State private var albumColorBg: Bool = AppConfig.coloredAlbumBackground
    @State private var playlistColorBg: Bool = AppConfig.coloredPlaylistBackground

    private var albumColorBinding: Binding<Bool> {
        Binding(
            get: { albumColorBg },
            set: { albumColorBg = $0; AppConfig.coloredAlbumBackground = $0 }
        )
    }

    private var playlistColorBinding: Binding<Bool> {
        Binding(
            get: { playlistColorBg },
            set: { playlistColorBg = $0; AppConfig.coloredPlaylistBackground = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                // Playback status
                Section("Status") {
                    HStack {
                        Text("Backend")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(store.isConnected ? Color.blue : Color.red)
                                .frame(width: 8, height: 8)
                            Text(store.isConnected ? "Online" : "Disconnected")
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Role")
                        Spacer()
                        Text(store.myRole.capitalized)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Client ID")
                        Spacer()
                        Text(String(store.myClientId.prefix(8)) + "…")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }

                    if !store.connectedClients.isEmpty {
                        HStack {
                            Text("Connected Clients")
                            Spacer()
                            Text("\(store.connectedClients.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Server info
                Section("Server") {
                    HStack {
                        Text("URL")
                        Spacer()
                        Text(AppConfig.serverURL ?? "—")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .lineLimit(1)
                    }

                    HStack {
                        Text("Username")
                        Spacer()
                        Text(AppConfig.username ?? "—")
                            .foregroundStyle(.secondary)
                    }
                }

                // Sync service
                Section("Sync Service") {
                    TextField("Sync URL (e.g. http://192.168.1.116:8080)", text: $syncURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onSubmit { saveSyncURL() }

                    Button(store.isConnected ? "Reconnect" : "Connect") {
                        saveSyncURL()
                        store.disconnect()
                        store.connect()
                    }
                    .disabled(syncURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                // Appearance
                Section("Appearance") {
                    Toggle("Album Color Background", isOn: albumColorBinding)
                    Toggle("Playlist Color Background", isOn: playlistColorBinding)
                }

                // Actions
                Section {
                    Button("Sign Out", role: .destructive) {
                        logout()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func logout() {
        store.disconnect()
        AppConfig.logout()
        isLoggedIn = false
    }

    private func saveSyncURL() {
        let trimmed = syncURL.trimmingCharacters(in: .whitespacesAndNewlines)
        AppConfig.syncServiceURL = trimmed.isEmpty ? nil : trimmed
    }
}
