// AppNavigationState.swift
// navidrome-sync — Observable navigation state injected at the root.
// Drives the custom tab-free navigation system (side rails + hamburger).

import SwiftUI
import Observation

// MARK: - App views

/// Every top-level screen in the app.
/// .nowPlaying and .library render directly inside the device shell (with click wheel).
/// All others are full-screen without a device shell.
enum AppView: Hashable, Equatable {
    case nowPlaying
    case library
    case albums
    case playlists
    case songs
    case artists
    case search
    case settings
}

// MARK: - Navigation state

@Observable
final class AppNavigationState {
    /// The currently visible top-level view.
    var currentView: AppView = .nowPlaying

    /// Whether the hamburger nav popover is visible.
    var isPopoverVisible: Bool = false

    // Per-view NavigationPath stacks for detail pushes
    var albumsPath     = NavigationPath()
    var playlistsPath  = NavigationPath()
    var songsPath      = NavigationPath()
    var artistsPath    = NavigationPath()
    var searchPath     = NavigationPath()
    var settingsPath   = NavigationPath()

    // MARK: - Helpers

    /// Navigate to a top-level view, resetting any pushed detail stack.
    func navigate(to view: AppView) {
        currentView = view
        isPopoverVisible = false
    }

    /// Handle a NavPopoverView destination selection.
    func handlePopoverSelection(_ dest: NavPopoverDestination) {
        switch dest {
        case .library:  navigate(to: .library)
        case .albums:   navigate(to: .albums)
        case .search:   navigate(to: .search)
        case .settings: navigate(to: .settings)
        }
    }
}
