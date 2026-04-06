import SwiftUI

@main
struct NavidromeApp: App {
    @StateObject private var syncStore = SyncStore()
    @StateObject private var playlistStore = PlaylistStore()
    @State private var isLoggedIn = AppConfig.isLoggedIn

    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                ContentView(isLoggedIn: $isLoggedIn)
                    .environmentObject(syncStore)
                    .environmentObject(playlistStore)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        playlistStore.bind(to: syncStore)
                        syncStore.connect()
                    }
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
                    .preferredColorScheme(.dark)
            }
        }
    }
}
