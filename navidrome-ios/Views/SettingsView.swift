import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SyncStore
    @EnvironmentObject private var downloadManager: DownloadManager
    @Binding var isLoggedIn: Bool
    @State private var syncURL: String = AppConfig.syncServiceURL ?? ""
    @State private var albumColorBg: Bool = AppConfig.coloredAlbumBackground
    @State private var playlistColorBg: Bool = AppConfig.coloredPlaylistBackground
    @State private var offlineMode: Bool = AppConfig.offlineMode
    @State private var autoCacheEnabled: Bool = AppConfig.autoCacheEnabled
    @State private var maxCacheSize: Int64 = AppConfig.maxCacheSize
    @State private var downloadQuality: Int = AppConfig.downloadQuality
    @State private var showClearAllAlert = false

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

    private var offlineModeBinding: Binding<Bool> {
        Binding(
            get: { offlineMode },
            set: {
                offlineMode = $0
                AppConfig.offlineMode = $0
                if $0 {
                    store.disconnect()
                } else {
                    store.connect()
                }
            }
        )
    }

    private var autoCacheBinding: Binding<Bool> {
        Binding(
            get: { autoCacheEnabled },
            set: { autoCacheEnabled = $0; AppConfig.autoCacheEnabled = $0 }
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
                                .fill(store.isConnected ? Color.brandPink : Color.brandRed)
                                .frame(width: 8, height: 8)
                            Text(store.isConnected ? "Online" : "Disconnected")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)

                    HStack {
                        Text("Role")
                        Spacer()
                        Text(store.myRole.capitalized)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)

                    HStack {
                        Text("Client ID")
                        Spacer()
                        Text(String(store.myClientId.prefix(8)) + "…")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .listRowBackground(Color.clear)

                    if !store.connectedClients.isEmpty {
                        HStack {
                            Text("Connected Clients")
                            Spacer()
                            Text("\(store.connectedClients.count)")
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.clear)
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
                    .listRowBackground(Color.clear)

                    HStack {
                        Text("Username")
                        Spacer()
                        Text(AppConfig.username ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }

                // Sync service
                Section("Sync Service") {
                    TextField("Sync URL (e.g. http://192.168.1.116:8080)", text: $syncURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onSubmit { saveSyncURL() }
                        .listRowBackground(Color.clear)

                    Button(store.isConnected ? "Reconnect" : "Connect") {
                        saveSyncURL()
                        store.disconnect()
                        store.connect()
                    }
                    .disabled(syncURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .listRowBackground(Color.clear)
                }

                // Appearance
                Section("Appearance") {
                    Toggle("Album Color Background", isOn: albumColorBinding)
                        .listRowBackground(Color.clear)
                    Toggle("Playlist Color Background", isOn: playlistColorBinding)
                        .listRowBackground(Color.clear)
                }

                // Downloads
                Section("Downloads") {
                    Toggle("Offline Mode", isOn: offlineModeBinding)
                        .listRowBackground(Color.clear)

                    NavigationLink {
                        DownloadsView()
                    } label: {
                        HStack {
                            Text("Manage Downloads")
                            Spacer()
                            Text(formatBytes(downloadManager.totalStorageUsed))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)

                    Toggle("Auto-Cache Played Songs", isOn: autoCacheBinding)
                        .listRowBackground(Color.clear)

                    if autoCacheEnabled {
                        Picker("Cache Limit", selection: Binding(
                            get: { maxCacheSize },
                            set: { maxCacheSize = $0; AppConfig.maxCacheSize = $0 }
                        )) {
                            Text("500 MB").tag(Int64(500 * 1024 * 1024))
                            Text("1 GB").tag(Int64(1024 * 1024 * 1024))
                            Text("2 GB").tag(Int64(2 * 1024 * 1024 * 1024))
                            Text("5 GB").tag(Int64(5 * 1024 * 1024 * 1024))
                            Text("Unlimited").tag(Int64(0))
                        }
                        .listRowBackground(Color.clear)
                    }

                    Picker("Download Quality", selection: Binding(
                        get: { downloadQuality },
                        set: { downloadQuality = $0; AppConfig.downloadQuality = $0 }
                    )) {
                        Text("Original").tag(0)
                        Text("High (320 kbps)").tag(320)
                        Text("Medium (192 kbps)").tag(192)
                        Text("Low (128 kbps)").tag(128)
                    }
                    .listRowBackground(Color.clear)

                    Button("Clear All Downloads", role: .destructive) {
                        showClearAllAlert = true
                    }
                    .listRowBackground(Color.clear)
                }

                // Actions
                Section {
                    Button("Sign Out", role: .destructive) {
                        logout()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background { store.dominantBackgroundColor.ignoresSafeArea() }
            .navigationTitle("Settings")
            .alert("Clear All Downloads?", isPresented: $showClearAllAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    downloadManager.removeAll()
                }
            } message: {
                Text("This will delete all downloaded files.")
            }
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

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
