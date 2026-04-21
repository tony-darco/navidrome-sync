// CrateColors.swift
// navidrome-sync — "Editorial Crate Digger" Design System (iOS)
//
// IMPORTANT: All hex values are copied verbatim from web/src/styles/design-system.ts.
// getCrateColor uses unicodeScalars.first!.value which matches JS charCodeAt(0)
// for the ASCII-range IDs that Navidrome generates (e.g. "a" → 97, "A" → 65).
// Do NOT substitute .utf8.first or .hash — they produce different indices.

import SwiftUI

// MARK: - CrateColorSet

struct CrateColorSet: Sendable {
    let name:      String
    // Device / UI surfaces
    let device:    Color
    let outer:     Color
    let ring:      Color
    let center:    Color
    let inner:     Color
    // Content / text
    let accent:    Color
    let text:      Color
    let light:     Color
    // Art zone
    let artBg:     Color
    let artLabel:  Color
    let artRing:   Color   // semi-transparent — colour already baked in
    // Mini player / popover
    let playerBg:  Color
    let pop:       Color
    // Progress / status
    let progFill:  Color
    let progBg:    Color   // semi-transparent
    // Pill
    let pillBg:    Color
    let pillText:  Color
    // Sync dot
    let dot:       Color
}

// MARK: - Crate palette (mirrors CRATE_COLORS in design-system.ts)

let CRATE_COLORS: [CrateColorSet] = [
    // 0 — Blue
    CrateColorSet(
        name:     "blue",
        device:   Color(hex: "#C8DFF5"),
        outer:    Color(hex: "#B5D4F4"),
        ring:     Color(hex: "#A8CBEE"),
        center:   Color(hex: "#D8E8F8"),
        inner:    Color(hex: "#CCDFF4"),
        accent:   Color(hex: "#185FA5"),
        text:     Color(hex: "#0C447C"),
        light:    Color(hex: "#B5D4F4"),
        artBg:    Color(hex: "#0C2A4A"),
        artLabel: Color(hex: "#1A4A7A"),
        artRing:  Color(hex: "#185FA5").opacity(1/3),
        playerBg: Color(hex: "#DAF0FF"),
        pop:      Color(hex: "#DAF0FF"),
        progFill: Color(hex: "#185FA5"),
        progBg:   Color(hex: "#185FA5").opacity(0.067),
        pillBg:   Color(hex: "#E6F1FB"),
        pillText: Color(hex: "#0C447C"),
        dot:      Color(hex: "#185FA5")
    ),
    // 1 — Amber
    CrateColorSet(
        name:     "amber",
        device:   Color(hex: "#F5D898"),
        outer:    Color(hex: "#FAC775"),
        ring:     Color(hex: "#F0BC65"),
        center:   Color(hex: "#FAD898"),
        inner:    Color(hex: "#F5D090"),
        accent:   Color(hex: "#BA7517"),
        text:     Color(hex: "#633806"),
        light:    Color(hex: "#FAC775"),
        artBg:    Color(hex: "#2A1800"),
        artLabel: Color(hex: "#4A2C00"),
        artRing:  Color(hex: "#BA7517").opacity(1/3),
        playerBg: Color(hex: "#FFF5DC"),
        pop:      Color(hex: "#FFF5DC"),
        progFill: Color(hex: "#BA7517"),
        progBg:   Color(hex: "#BA7517").opacity(0.067),
        pillBg:   Color(hex: "#FAEEDA"),
        pillText: Color(hex: "#633806"),
        dot:      Color(hex: "#BA7517")
    ),
    // 2 — Coral
    CrateColorSet(
        name:     "coral",
        device:   Color(hex: "#F0C4B0"),
        outer:    Color(hex: "#F5C4B3"),
        ring:     Color(hex: "#EDB8A5"),
        center:   Color(hex: "#F5CFC3"),
        inner:    Color(hex: "#EEC8BA"),
        accent:   Color(hex: "#993C1D"),
        text:     Color(hex: "#712B13"),
        light:    Color(hex: "#F5C4B3"),
        artBg:    Color(hex: "#2A0C04"),
        artLabel: Color(hex: "#4A1808"),
        artRing:  Color(hex: "#993C1D").opacity(1/3),
        playerBg: Color(hex: "#FDE8DF"),
        pop:      Color(hex: "#FDE8DF"),
        progFill: Color(hex: "#993C1D"),
        progBg:   Color(hex: "#993C1D").opacity(0.067),
        pillBg:   Color(hex: "#FAECE7"),
        pillText: Color(hex: "#712B13"),
        dot:      Color(hex: "#993C1D")
    ),
    // 3 — Green
    CrateColorSet(
        name:     "green",
        device:   Color(hex: "#C4DC98"),
        outer:    Color(hex: "#C0DD97"),
        ring:     Color(hex: "#B2D288"),
        center:   Color(hex: "#CCE4A2"),
        inner:    Color(hex: "#C4DC9A"),
        accent:   Color(hex: "#3B6D11"),
        text:     Color(hex: "#27500A"),
        light:    Color(hex: "#C0DD97"),
        artBg:    Color(hex: "#0A1E04"),
        artLabel: Color(hex: "#183808"),
        artRing:  Color(hex: "#3B6D11").opacity(1/3),
        playerBg: Color(hex: "#E8F8D4"),
        pop:      Color(hex: "#E8F8D4"),
        progFill: Color(hex: "#3B6D11"),
        progBg:   Color(hex: "#3B6D11").opacity(0.067),
        pillBg:   Color(hex: "#EAF3DE"),
        pillText: Color(hex: "#27500A"),
        dot:      Color(hex: "#3B6D11")
    ),
    // 4 — Purple
    CrateColorSet(
        name:     "purple",
        device:   Color(hex: "#CBC8F0"),
        outer:    Color(hex: "#CECBF6"),
        ring:     Color(hex: "#C0BCF0"),
        center:   Color(hex: "#D8D5F8"),
        inner:    Color(hex: "#CECBF4"),
        accent:   Color(hex: "#534AB7"),
        text:     Color(hex: "#3C3489"),
        light:    Color(hex: "#CECBF6"),
        artBg:    Color(hex: "#100E30"),
        artLabel: Color(hex: "#201C58"),
        artRing:  Color(hex: "#534AB7").opacity(1/3),
        playerBg: Color(hex: "#EEEEFF"),
        pop:      Color(hex: "#EEEEFF"),
        progFill: Color(hex: "#534AB7"),
        progBg:   Color(hex: "#534AB7").opacity(0.067),
        pillBg:   Color(hex: "#EEEDFE"),
        pillText: Color(hex: "#3C3489"),
        dot:      Color(hex: "#534AB7")
    ),
    // 5 — Teal
    CrateColorSet(
        name:     "teal",
        device:   Color(hex: "#A4DCC8"),
        outer:    Color(hex: "#9FE1CB"),
        ring:     Color(hex: "#90D4BE"),
        center:   Color(hex: "#B0E4D4"),
        inner:    Color(hex: "#A8DCCC"),
        accent:   Color(hex: "#0F6E56"),
        text:     Color(hex: "#085041"),
        light:    Color(hex: "#9FE1CB"),
        artBg:    Color(hex: "#021A14"),
        artLabel: Color(hex: "#063028"),
        artRing:  Color(hex: "#0F6E56").opacity(1/3),
        playerBg: Color(hex: "#D8F5EB"),
        pop:      Color(hex: "#D8F5EB"),
        progFill: Color(hex: "#0F6E56"),
        progBg:   Color(hex: "#0F6E56").opacity(0.067),
        pillBg:   Color(hex: "#E1F5EE"),
        pillText: Color(hex: "#085041"),
        dot:      Color(hex: "#0F6E56")
    ),
]

// MARK: - Lookup

/// Returns the crate color set deterministically from an album ID.
/// Matches JS: CRATE_COLORS[albumId.charCodeAt(0) % 6]
/// Uses unicodeScalars.first!.value — identical to charCodeAt(0) for ASCII Navidrome IDs.
func getCrateColor(albumId: String) -> CrateColorSet {
    guard let scalar = albumId.unicodeScalars.first else {
        return CRATE_COLORS[0]
    }
    let index = Int(scalar.value) % CRATE_COLORS.count
    return CRATE_COLORS[index]
}
