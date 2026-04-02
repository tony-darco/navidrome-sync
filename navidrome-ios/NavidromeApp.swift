import SwiftUI

@main
struct NavidromeApp: App {
    @StateObject private var syncStore = SyncStore()
    @State private var isLoggedIn = AppConfig.isLoggedIn

    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                ContentView(isLoggedIn: $isLoggedIn)
                    .environmentObject(syncStore)
                    .preferredColorScheme(.dark)
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
                    .preferredColorScheme(.dark)
            }
        }
    }
}
