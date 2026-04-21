// NavPopoverView.swift
// navidrome-sync — Hamburger nav popover, anchored bottom-left.
// Springs in/out. Background tinted to crate.pop. Tapping outside dismisses.

import SwiftUI

// Destinations available from the hamburger nav (spec: Library ♪ | Albums ◉ | Search ⌕ | Settings ⚙)
enum NavPopoverDestination: Hashable {
    case library, albums, search, settings
}

struct NavPopoverView: View {
    @Binding var isVisible: Bool
    let crate: CrateColorSet
    let onNavigate: (NavPopoverDestination) -> Void

    @State private var appeared = false

    private let items: [(label: String, icon: String, dest: NavPopoverDestination)] = [
        ("Library",  "♪", .library),
        ("Albums",   "◉", .albums),
        ("Search",   "⌕", .search),
        ("Settings", "⚙", .settings),
    ]

    var body: some View {
        if isVisible {
            ZStack(alignment: .bottomLeading) {

                // ── Transparent tap-dismiss backdrop ──────────────────────────
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }

                // ── Popover box ───────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(items, id: \.dest) { item in
                        Button {
                            dismiss()
                            onNavigate(item.dest)
                        } label: {
                            HStack(spacing: DesignSpacing.sm) {
                                Text(item.icon)
                                    .font(.system(size: 14))
                                    .frame(width: 22, alignment: .center)
                                Text(item.label)
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                            }
                            .foregroundStyle(crate.text)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, DesignSpacing.md)
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)

                        if item.dest != .settings {
                            Divider()
                                .opacity(0.18)
                                .padding(.leading, DesignSpacing.md + 22 + DesignSpacing.sm)
                        }
                    }
                }
                .frame(width: DesignDim.navPopoverWidth)
                .background(crate.pop)
                .clipShape(RoundedRectangle(cornerRadius: DesignDim.navPopoverRadius))
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
                // Anchored just above the bottom nav, inset from the left rail
                .padding(.leading, DesignDim.sideBarWidth + DesignSpacing.md)
                .padding(.bottom, DesignDim.bottomNavHeight + DesignSpacing.sm)
                .scaleEffect(appeared ? 1.0 : 0.85, anchor: .bottomLeading)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(DesignAnim.popoverIn, value: appeared)
            }
            .ignoresSafeArea()
            .onAppear { appeared = true }
        }
    }

    private func dismiss() {
        withAnimation(DesignAnim.popoverIn) { appeared = false }
        // Wait for animation to finish before hiding from hierarchy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isVisible = false
        }
    }
}
