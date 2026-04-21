import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        DownloadManager.shared.backgroundCompletionHandler = completionHandler
    }
}

@main
struct NavidromeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var syncStore = SyncStore()
    @StateObject private var playlistStore = PlaylistStore()
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var musicLibraryStore = MusicLibraryStore()
    @State private var isLoggedIn = AppConfig.isLoggedIn

    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                ContentView(isLoggedIn: $isLoggedIn)
                    .environmentObject(syncStore)
                    .environmentObject(playlistStore)
                    .environmentObject(downloadManager)
                    .environmentObject(musicLibraryStore)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        playlistStore.bind(to: syncStore)
                        syncStore.bind(to: musicLibraryStore)
                        syncStore.connect()
                    }
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
                    .preferredColorScheme(.dark)
            }
        }
    }
}
