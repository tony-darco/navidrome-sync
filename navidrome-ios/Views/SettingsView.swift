import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SyncStore
    @Binding var isLoggedIn: Bool

    var body: some View {
        NavigationStack {
            List {
                // Connection status
                Section("Connection") {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(store.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(store.isConnected ? "Connected" : "Disconnected")
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
}
