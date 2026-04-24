import SwiftUI

/// Observes scroll geometry on any List or ScrollView and collapses/expands
/// the mini player pill via `SyncStore.miniPlayerCollapsed`.
struct MiniPlayerScrollObserver: ViewModifier {
    @EnvironmentObject private var store: SyncStore

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: Double.self) { geometry in
                    geometry.contentOffset.y
                } action: { oldValue, newValue in
                    // Require a meaningful movement to avoid micro-jitter
                    guard abs(newValue - oldValue) > 4 else { return }
                    let scrollingDown = newValue > oldValue && newValue > 20
                    if scrollingDown != store.miniPlayerCollapsed {
                        store.miniPlayerCollapsed = scrollingDown
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    /// Collapses the mini player pill when the user scrolls down.
    func miniPlayerScrollObserver() -> some View {
        modifier(MiniPlayerScrollObserver())
    }
}
