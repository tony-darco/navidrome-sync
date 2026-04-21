import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SyncStore
    @EnvironmentObject private var downloadManager: DownloadManager
    @Environment(AppNavigationState.self) private var nav
    @Environment(CrateColorState.self) private var crateState

    @Binding var isLoggedIn: Bool

    // Server section
    @State private var syncURL: String = AppConfig.syncServiceURL ?? ""

    // Sync section
    @State private var offlineMode: Bool    = AppConfig.offlineMode
    @State private var autoCacheEnabled: Bool = AppConfig.autoCacheEnabled
    @State private var maxCacheSize: Int64  = AppConfig.maxCacheSize
    @State private var downloadQuality: Int = AppConfig.downloadQuality

    @State private var showClearAllAlert = false
    @State private var showSyncURLEditor = false

    @AppStorage("albumIsGrid") private var isGrid: Bool = false

    // Crate color override index (-1 = Auto)
    @State private var crateOverrideIndex: Int = {
        if UserDefaults.standard.bool(forKey: "crateColorOverride_set") {
            return UserDefaults.standard.integer(forKey: "crateColorOverride_raw")
        }
        return -1
    }()

    var body: some View {
        @Bindable var nav = nav

        NavigationStack(path: $nav.settingsPath) {
            ZStack(alignment: .bottomLeading) {
                DesignBg.cream.ignoresSafeArea()

                List {
                    // MARK: Server
                    Section {
                        settingsRow(label: "Server URL") {
                            Text(AppConfig.serverURL ?? "—")
                                .font(.system(size: 13))
                                .foregroundStyle(DesignText.secondary)
                                .lineLimit(1)
                        }
                        settingsRow(label: "Username") {
                            Text(AppConfig.username ?? "—")
                                .font(.system(size: 13))
                                .foregroundStyle(DesignText.secondary)
                        }
                        settingsRow(label: "Password") {
                            Text("••••••••")
                                .font(.system(size: 13))
                                .foregroundStyle(DesignText.secondary)
                        }
                        settingsRow(label: "Status") {
                            connectionBadge
                        }
                    } header: {
                        sectionLabel("Server")
                    }
                    .listRowBackground(DesignBg.card)

                    // MARK: Appearance
                    Section {
                        VStack(alignment: .leading, spacing: DesignSpacing.md) {
                            Text("Crate Color")
                                .font(.system(size: 15))
                                .foregroundStyle(DesignText.primary)

                            crateColorPicker
                                .padding(.bottom, DesignSpacing.xs)
                        }
                        .listRowBackground(DesignBg.card)

                        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                            Text("Album View")
                                .font(.system(size: 15))
                                .foregroundStyle(DesignText.primary)

                            Picker("Album View", selection: $isGrid) {
                                Text("Crate Flow").tag(false)
                                Text("Grid").tag(true)
                            }
                            .pickerStyle(.segmented)
                        }
                        .listRowBackground(DesignBg.card)
                    } header: {
                        sectionLabel("Appearance")
                    }

                    // MARK: Sync
                    Section {
                        settingsRow(label: "Sync Service URL") {
                            TextField("http://...", text: $syncURL)
                                .font(.system(size: 13))
                                .foregroundStyle(DesignText.secondary)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .onSubmit { saveSyncURL(); reconnect() }
                        }

                        HStack {
                            Toggle("Sync on Wi-Fi Only", isOn: .constant(true))
                                .font(.system(size: 15))
                                .tint(crateState.current.accent)
                        }
                        .listRowBackground(DesignBg.card)

                        HStack {
                            Toggle("Cache Album Art", isOn: Binding(
                                get: { autoCacheEnabled },
                                set: { autoCacheEnabled = $0; AppConfig.autoCacheEnabled = $0 }
                            ))
                            .font(.system(size: 15))
                            .tint(crateState.current.accent)
                        }
                        .listRowBackground(DesignBg.card)

                        settingsRow(label: "Offline Cache") {
                            Picker("", selection: Binding(
                                get: { maxCacheSize },
                                set: { maxCacheSize = $0; AppConfig.maxCacheSize = $0 }
                            )) {
                                Text("512 MB").tag(Int64(512 * 1024 * 1024))
                                Text("1 GB").tag(Int64(1024 * 1024 * 1024))
                                Text("2 GB").tag(Int64(2 * 1024 * 1024 * 1024))
                                Text("4 GB").tag(Int64(4 * 1024 * 1024 * 1024))
                                Text("8 GB").tag(Int64(8 * 1024 * 1024 * 1024))
                            }
                            .pickerStyle(.menu)
                            .tint(crateState.current.accent)
                        }

                        settingsRow(label: "Stream Quality") {
                            Picker("", selection: Binding(
                                get: { downloadQuality },
                                set: { downloadQuality = $0; AppConfig.downloadQuality = $0 }
                            )) {
                                Text("96 kbps").tag(96)
                                Text("128 kbps").tag(128)
                                Text("256 kbps").tag(256)
                                Text("320 kbps").tag(320)
                            }
                            .pickerStyle(.menu)
                            .tint(crateState.current.accent)
                        }

                        HStack {
                            Toggle("Offline Mode", isOn: Binding(
                                get: { offlineMode },
                                set: {
                                    offlineMode = $0; AppConfig.offlineMode = $0
                                    if $0 { store.disconnect() } else { store.connect() }
                                }
                            ))
                            .font(.system(size: 15))
                            .tint(crateState.current.accent)
                        }
                        .listRowBackground(DesignBg.card)
                    } header: {
                        sectionLabel("Sync")
                    }
                    .listRowBackground(DesignBg.card)

                    // MARK: About
                    Section {
                        settingsRow(label: "Version") {
                            Text(appVersion)
                                .font(.system(size: 13))
                                .foregroundStyle(DesignText.secondary)
                        }
                        settingsRow(label: "Last Synced") {
                            Text(lastSyncedText)
                                .font(.system(size: 13))
                                .foregroundStyle(DesignText.secondary)
                        }
                    } header: {
                        sectionLabel("About")
                    }
                    .listRowBackground(DesignBg.card)

                    // MARK: Actions
                    Section {
                        Button("Clear All Downloads", role: .destructive) {
                            showClearAllAlert = true
                        }
                        .font(.system(size: 15))
                        .listRowBackground(DesignBg.card)

                        Button("Sign Out", role: .destructive) {
                            logout()
                        }
                        .font(.system(size: 15))
                        .listRowBackground(DesignBg.card)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(DesignBg.cream)
                // padding for bottom nav
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 60) }

                bottomNav
                    .frame(maxWidth: .infinity, alignment: .bottom)

                NavPopoverView(
                    isVisible: Binding(
                        get: { nav.isPopoverVisible },
                        set: { nav.isPopoverVisible = $0 }
                    ),
                    crate: crateState.current,
                    onNavigate: { nav.handlePopoverSelection($0) }
                )
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Clear All Downloads?", isPresented: $showClearAllAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) { downloadManager.removeAll() }
            } message: {
                Text("This will delete all downloaded files.")
            }
        }
    }

    // MARK: - Connection status badge

    private var connectionBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(store.isConnected ? DesignStatus.syncedDot : DesignStatus.errorDot)
                .frame(width: 7, height: 7)
            Text(store.isConnected ? "Connected" : "Disconnected")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(store.isConnected ? DesignStatus.syncedText : DesignStatus.errorText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(store.isConnected ? DesignStatus.syncedBg : DesignStatus.errorBg)
        .clipShape(Capsule())
    }

    // MARK: - Crate color picker

    private var crateColorPicker: some View {
        HStack(spacing: DesignSpacing.sm) {
            // Auto swatch (gradient)
            Button {
                crateOverrideIndex = -1
                crateState.clearOverride()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: CRATE_COLORS.map(\.accent),
                                center: .center
                            )
                        )
                    if crateOverrideIndex == -1 {
                        Circle()
                            .stroke(DesignText.primary, lineWidth: 2)
                    }
                }
                .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            ForEach(Array(CRATE_COLORS.enumerated()), id: \.offset) { idx, crate in
                Button {
                    crateOverrideIndex = idx
                    crateState.applyOverride(index: idx)
                } label: {
                    ZStack {
                        Circle().fill(crate.device)
                        Circle()
                            .stroke(crate.accent, lineWidth: 1.5)
                        if crateOverrideIndex == idx {
                            Circle()
                                .stroke(DesignText.primary, lineWidth: 2)
                        }
                    }
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    // MARK: - Helper views

    @ViewBuilder
    private func settingsRow<T: View>(label: String, @ViewBuilder content: () -> T) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(DesignText.primary)
            Spacer()
            content()
        }
        .listRowBackground(DesignBg.card)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: DesignType.sectionLabel.size, weight: DesignType.sectionLabel.weight))
            .tracking(DesignType.tracking(from: DesignType.sectionLabel))
            .textCase(.uppercase)
            .foregroundStyle(DesignText.secondary)
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        HStack {
            Button { nav.isPopoverVisible = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignText.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("navidrome-sync")
                .font(.system(size: 11, weight: .semibold))
                .tracking(DesignType.tracking(from: DesignType.sectionLabel))
                .textCase(.uppercase)
                .foregroundStyle(DesignText.secondary)
        }
        .padding(.horizontal, DesignSpacing.lg)
        .padding(.vertical, DesignSpacing.md)
        .background(DesignBg.cream)
    }

    // MARK: - Computed info

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    private var lastSyncedText: String {
        // AppConfig does not currently expose lastSyncedDate; use store's last activity as proxy
        return "—"
    }

    // MARK: - Actions

    private func logout() {
        store.disconnect()
        AppConfig.logout()
        isLoggedIn = false
    }

    private func saveSyncURL() {
        let trimmed = syncURL.trimmingCharacters(in: .whitespacesAndNewlines)
        AppConfig.syncServiceURL = trimmed.isEmpty ? nil : trimmed
    }

    private func reconnect() {
        store.disconnect()
        store.connect()
    }
}
