// VinylFallbackView.swift
// navidrome-sync — Fallback art when no Navidrome cover art is available.
// Renders a stylised vinyl record SVG using the current crate color.

import SwiftUI

struct VinylFallbackView: View {
    let crate: CrateColorSet
    var size: CGFloat = 200
    var artistName: String? = nil
    var albumTitle: String? = nil

    // The groove rings sit at these fractions of the outer radius
    private let grooveFractions: [CGFloat] = [0.88, 0.72, 0.56]
    // Groove opacity values (inner → outer, matches spec 33–55%)
    private let grooveOpacities: [Double] = [0.55, 0.44, 0.33]

    private var radius: CGFloat { size / 2 }
    private var centerLabelRadius: CGFloat { radius * 0.30 }
    private var centerHoleRadius: CGFloat  { radius * 0.06 }

    var body: some View {
        ZStack {
            // ── Outer disc ──────────────────────────────────────────────
            Circle()
                .fill(crate.artBg)
                .frame(width: size, height: size)

            // ── Groove rings ────────────────────────────────────────────
            ForEach(Array(grooveFractions.enumerated()), id: \.offset) { i, fraction in
                Circle()
                    .stroke(crate.accent.opacity(grooveOpacities[i]), lineWidth: 1.5)
                    .frame(width: size * fraction, height: size * fraction)
            }

            // ── Center label circle ─────────────────────────────────────
            Circle()
                .fill(crate.artLabel)
                .frame(width: centerLabelRadius * 2, height: centerLabelRadius * 2)

            // ── Optional text (artist / album) ──────────────────────────
            if artistName != nil || albumTitle != nil {
                VStack(spacing: 2) {
                    if let artist = artistName {
                        Text(artist)
                            .font(.system(size: max(7, size * 0.052), weight: .semibold))
                            .foregroundStyle(crate.light)
                            .lineLimit(1)
                    }
                    if let album = albumTitle {
                        Text(album)
                            .font(.system(size: max(6, size * 0.040), weight: .regular))
                            .foregroundStyle(crate.light.opacity(0.75))
                            .lineLimit(1)
                    }
                }
                .frame(width: centerLabelRadius * 1.7)
            }

            // ── Center hole ─────────────────────────────────────────────
            Circle()
                .fill(crate.accent)
                .frame(width: centerHoleRadius * 2, height: centerHoleRadius * 2)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 16) {
        VinylFallbackView(crate: CRATE_COLORS[0], size: 140,
                          artistName: "Artist", albumTitle: "Album")
        VinylFallbackView(crate: CRATE_COLORS[3], size: 100)
        VinylFallbackView(crate: CRATE_COLORS[5], size: 60)
    }
    .padding()
    .background(Color.black)
}
