// DesignTokens.swift
// navidrome-sync — "Editorial Crate Digger" Design System (iOS)
//
// All values mirror web/src/styles/design-system.ts exactly.
// Never hardcode colors, spacing, or radii in components — use these constants.

import SwiftUI

// MARK: - Color(hex:) extension

extension Color {
    /// Initialises a SwiftUI Color from a CSS hex string.
    /// Supports "#RRGGBB" and "#RRGGBBAA" (8-digit / 4-digit with alpha).
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let r, g, b, a: Double
        switch hex.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >>  8) & 0xFF) / 255
            b = Double( value        & 0xFF) / 255
            a = 1.0
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >>  8) & 0xFF) / 255
            a = Double( value        & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Backgrounds (mirrors BACKGROUNDS)

enum DesignBg {
    /// Light views: Library, Songs, Artists, Search, Settings, Playlists
    static let cream         = Color(hex: "#F7F5F0")
    static let creamHover    = Color(hex: "#F0EDE5")
    static let creamActive   = Color(hex: "#EAE7DF")
    /// Now Playing
    static let playerDark    = Color(hex: "#0A0A0A")
    static let playerCard    = Color(hex: "#1A1A1A")
    /// White card groups (Settings)
    static let card          = Color.white
}

// MARK: - Text (mirrors TEXT)

enum DesignText {
    static let primary       = Color(hex: "#1A1A1A")
    static let secondary     = Color.black.opacity(0.45)
    static let tertiary      = Color.black.opacity(0.28)
    static let muted         = Color.black.opacity(0.18)
    static let onDark        = Color.white
    static let onDarkMuted   = Color.white.opacity(0.5)
    static let onDarkHint    = Color.white.opacity(0.3)
}

// MARK: - Status (mirrors STATUS)

enum DesignStatus {
    static let syncedBg      = Color(hex: "#D4F5E3")
    static let syncedText    = Color(hex: "#0D5C32")
    static let syncedDot     = Color(hex: "#1A9E5C")
    static let syncingBg     = Color(hex: "#FFF3D6")
    static let syncingText   = Color(hex: "#7A4E00")
    static let syncingDot    = Color(hex: "#E09000")
    static let errorBg       = Color(hex: "#FFE8E8")
    static let errorText     = Color(hex: "#8B1A1A")
    static let errorDot      = Color(hex: "#D63030")
}

// MARK: - Typography (mirrors TYPOGRAPHY)
// Sizes in points (iOS pt = web px at 1:1 for the values in design-system)

enum DesignType {
    struct Spec {
        let size:       CGFloat
        let weight:     Font.Weight
        /// em units — apply via .tracking(size * tracking) in SwiftUI
        let tracking:   CGFloat
        let lineHeight: CGFloat
    }

    static let display     = Spec(size: 40, weight: .bold,    tracking: -0.03, lineHeight: 1.0)
    static let h1          = Spec(size: 32, weight: .bold,    tracking: -0.02, lineHeight: 1.1)
    static let h2          = Spec(size: 22, weight: .medium,  tracking:  0,    lineHeight: 1.2)
    static let sectionLabel = Spec(size: 11, weight: .semibold, tracking: 0.10, lineHeight: 1.0)
    static let body        = Spec(size: 15, weight: .regular, tracking:  0,    lineHeight: 1.6)
    static let rowTitle    = Spec(size: 13, weight: .semibold, tracking: 0,    lineHeight: 1.0)
    static let rowSub      = Spec(size: 10, weight: .regular, tracking:  0,    lineHeight: 1.0)

    /// Applies size + weight from a Spec; caller handles lineHeight via padding if needed.
    static func font(from spec: Spec) -> Font {
        .system(size: spec.size, weight: spec.weight)
    }

    /// Tracking value for SwiftUI's .tracking() modifier (size * em_tracking).
    static func tracking(from spec: Spec) -> CGFloat {
        spec.size * spec.tracking
    }
}

// MARK: - Spacing (mirrors SPACING)

enum DesignSpacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 20
    static let xxl: CGFloat = 28
}

// MARK: - Border radius (mirrors RADIUS)

enum DesignRadius {
    static let sm:      CGFloat = 6
    static let md:      CGFloat = 8
    static let lg:      CGFloat = 12   // Cards, playlist cards, mini player
    static let xl:      CGFloat = 16
    static let pill:    CGFloat = 20   // Genre tags, status pills
    static let circle:  CGFloat = 9999 // Avatars, vinyl dots
    static let device:  CGFloat = 32
    static let screen:  CGFloat = 14
    static let sideBar: CGFloat = 6
}

// MARK: - Borders (mirrors BORDERS)

enum DesignBorder {
    static let subtle:   Color = .black.opacity(0.06)
    static let light:    Color = .black.opacity(0.08)
    static let medium:   Color = .black.opacity(0.12)
    static let onDark:   Color = .white.opacity(0.10)
    static let width:    CGFloat = 0.5
}

// MARK: - Dimensions (mirrors DIMENSIONS)

enum DesignDim {
    // iOS device shell
    static let deviceWidth:      CGFloat = 300
    static let sideBarWidth:     CGFloat = 14
    static let screenHeight:     CGFloat = 315
    static let notchWidth:       CGFloat = 80
    static let notchHeight:      CGFloat = 22
    // Click wheel
    static let wheelDiameter:    CGFloat = 190
    static let wheelRingInset:   CGFloat = 4
    static let wheelCenterInset: CGFloat = 55
    static let wheelCenterInner: CGFloat = 66
    // Ring interaction zones (as fraction of radius)
    static let ringInnerFraction: CGFloat = 0.38
    static let ringOuterFraction: CGFloat = 0.93
    // Row heights
    static let crateRowHeight:   CGFloat = 82
    static let listRowHeight:    CGFloat = 58
    // Thumbnails
    static let thumbSm:          CGFloat = 34
    static let thumbMd:          CGFloat = 36
    static let thumbLg:          CGFloat = 52
    // Album chip
    static let albumChipSize:    CGFloat = 80
    // Mini player
    static let miniPlayerRadius: CGFloat = 12
    static let miniProgressH:    CGFloat = 2
    // Bottom nav
    static let bottomNavHeight:  CGFloat = 46
    // Nav popover
    static let navPopoverWidth:  CGFloat = 148
    static let navPopoverRadius: CGFloat = 12
}

// MARK: - CoverFlow (mirrors COVER_FLOW)

enum DesignCoverFlow {
    static let artSize:           CGFloat = 180
    static let spacing:           CGFloat = 230
    static let sideRotateX:       Double  = 52      // degrees
    static let sideScale:         CGFloat = 0.58
    static let sideScaleDecay:    CGFloat = 0.14    // per step
    static let opacityDecay:      Double  = 0.55    // per step
    static let reflectionHeight:  CGFloat = 54
    static let reflectionOpacity: Double  = 0.22
    static let visibleRadius:     Int     = 3
}

// MARK: - Animation (mirrors TRANSITIONS)

enum DesignAnim {
    /// Crate color transitions — matches 'background 0.5s ease' CSS
    static let crateColor = Animation.easeInOut(duration: 0.5)
    /// Nav popover spring
    static let popoverIn  = Animation.spring(response: 0.2, dampingFraction: 0.7)
    /// CoverFlow card
    static let coverFlow  = Animation.timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.38)
    /// Row/card press
    static let rowPress   = Animation.easeInOut(duration: 0.12)
    /// Swatch select
    static let swatch     = Animation.easeInOut(duration: 0.15)
}

// MARK: - Click Wheel labels (mirrors CLICK_WHEEL.labels)

enum DesignWheel {
    static let top    = "+"
    static let bottom = "−"
    static let left   = "◀◀"
    static let right  = "▶▶"
    static let play   = "▶"
    static let pause  = "⏸"
}

// MARK: - Settings options (mirrors SETTINGS_OPTIONS)

enum DesignSettings {
    static let syncIntervals = ["1 min", "5 min", "15 min", "30 min", "1 hr", "Manual"]
    static let cacheSizes    = ["512 MB", "1 GB", "2 GB", "4 GB", "8 GB"]
    static let qualities     = ["96 kbps", "128 kbps", "256 kbps", "320 kbps"]
}
