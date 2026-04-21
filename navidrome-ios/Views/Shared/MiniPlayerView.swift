// MiniPlayerView.swift
// navidrome-sync — Persistent mini player shown between content and the bottom nav
// on all full-screen views (Playlists, Songs, Artists, Search).
// Background transitions to the current track's crate.playerBg color (0.5s ease).
// Tap art or track info → navigates to Now Playing.

import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var store: SyncStore
    let crate: CrateColorSet
    /// Navigate to Now Playing when the user taps the art or track info.
    let onTapToNowPlaying: () -> Void

    private var progressFraction: CGFloat {
        guard let song = store.nowPlaying, song.durationSecs > 0 else { return 0 }
        return CGFloat(store.position) / CGFloat(song.durationSecs)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── 2 px progress bar ─────────────────────────────────────────────
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(crate.progBg)
                    Rectangle()
                        .fill(crate.progFill)
                        .frame(width: geo.size.width * progressFraction)
                }
            }
            .frame(height: DesignDim.miniProgressH)

            // ── Main row ──────────────────────────────────────────────────────
            HStack(spacing: DesignSpacing.sm) {

                if let song = store.nowPlaying {
                    // Art + info — tappable → Now Playing
                    Button(action: onTapToNowPlaying) {
                        HStack(spacing: DesignSpacing.sm) {
                            // Thumbnail
                            CoverArtImage(id: song.coverArtId, size: 72)
                                .frame(width: DesignDim.thumbSm, height: DesignDim.thumbMd)
                                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))

                            // Track info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title)
                                    .font(DesignType.font(from: DesignType.rowTitle))
                                    .foregroundStyle(DesignText.primary)
                                    .lineLimit(1)
                                Text(song.artist)
                                    .font(DesignType.font(from: DesignType.rowSub))
                                    .foregroundStyle(DesignText.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    // Nothing playing — empty placeholder keeps height stable
                    HStack(spacing: DesignSpacing.sm) {
                        RoundedRectangle(cornerRadius: DesignRadius.sm)
                            .fill(DesignText.muted)
                            .frame(width: DesignDim.thumbSm, height: DesignDim.thumbMd)
                        Text("Nothing playing")
                            .font(DesignType.font(from: DesignType.rowSub))
                            .foregroundStyle(DesignText.muted)
                        Spacer()
                    }
                }

                // ── Transport controls ─────────────────────────────────────────
                HStack(spacing: DesignSpacing.lg) {
                    controlButton(icon: "backward.end.fill", action: { store.prev() })
                    controlButton(
                        icon: store.isPlaying ? "pause.fill" : "play.fill",
                        action: {
                            if store.isPlaying { store.pause() } else { store.play() }
                        }
                    )
                    controlButton(icon: "forward.end.fill", action: { store.next() })
                }
            }
            .padding(.horizontal, DesignSpacing.lg)
            .padding(.vertical, DesignSpacing.sm)
            .frame(minHeight: 56)
        }
        .background(crate.playerBg.animation(DesignAnim.crateColor))
    }

    @ViewBuilder
    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(crate.accent)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }
}
