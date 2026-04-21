// MiniTrackStripView.swift
// navidrome-sync — Compact playback strip pinned to the bottom of the Library graphic zone.
// Shows: album art | track title + artist | play/pause toggle.
// Tapping the art or track info navigates to Now Playing.

import SwiftUI

struct MiniTrackStripView: View {
    @EnvironmentObject private var store: SyncStore
    /// Called when the user taps the art or track info (navigate to Now Playing).
    let onTap: () -> Void

    var body: some View {
        if let song = store.nowPlaying {
            HStack(spacing: DesignSpacing.sm) {

                // ── Art + info (tappable → Now Playing) ──────────────────────
                Button(action: onTap) {
                    HStack(spacing: DesignSpacing.sm) {
                        // Album art thumbnail
                        CoverArtImage(id: song.coverArtId, size: 72)
                            .frame(width: DesignDim.thumbMd, height: DesignDim.thumbMd)
                            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))

                        // Track title + artist
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DesignText.onDark)
                                .lineLimit(1)
                            Text(song.artist)
                                .font(.system(size: 10))
                                .foregroundStyle(DesignText.onDarkMuted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)

                // ── Play / pause ──────────────────────────────────────────────
                Button {
                    if store.isPlaying { store.pause() } else { store.play() }
                } label: {
                    Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DesignText.onDark)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignSpacing.lg)
            .padding(.vertical, DesignSpacing.sm)
            // Semi-dark background matching spec
            .background(Color.black.opacity(0.25))
            // 0.5pt top border per spec
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 0.5)
            }
        }
    }
}
