// CrateColorEnvironment.swift
// navidrome-sync — Observable crate color state injected at the root.
// All views read @Environment(CrateColorState.self) to get/react to the
// current crate color. Call update(albumId:) whenever the playing track changes.

import SwiftUI
import Observation

@Observable
final class CrateColorState {
    /// The active crate color set — changes when the playing album changes.
    var current: CrateColorSet = CRATE_COLORS[0]

    // ── Override support (Settings → Appearance) ───────────────────────
    // -1 = auto (follows track), 0–5 = fixed crate index
    var overrideIndex: Int {
        get { UserDefaults.standard.integer(forKey: "crateColorOverride_raw") }
        set { UserDefaults.standard.set(newValue, forKey: "crateColorOverride_raw") }
    }
    var isAutoMode: Bool { storedOverrideIndex == -1 }

    // We store -1 as a sentinel: UserDefaults returns 0 for missing keys, so
    // we use a separate key for "has been set" to differentiate 0 (blue fixed)
    // from "not set" (auto).
    private var storedOverrideIndex: Int {
        guard UserDefaults.standard.bool(forKey: "crateColorOverride_set") else { return -1 }
        return UserDefaults.standard.integer(forKey: "crateColorOverride_raw")
    }

    func setOverride(index: Int) {
        // index -1 = auto
        if index < 0 {
            UserDefaults.standard.removeObject(forKey: "crateColorOverride_raw")
            UserDefaults.standard.set(false, forKey: "crateColorOverride_set")
        } else {
            UserDefaults.standard.set(index, forKey: "crateColorOverride_raw")
            UserDefaults.standard.set(true, forKey: "crateColorOverride_set")
        }
    }

    // ── Update from playing track ──────────────────────────────────────
    /// Call this whenever `nowPlaying?.albumId` changes.
    func update(albumId: String) {
        let idx = storedOverrideIndex
        let newCrate: CrateColorSet
        if idx >= 0 && idx < CRATE_COLORS.count {
            newCrate = CRATE_COLORS[idx]
        } else {
            newCrate = getCrateColor(albumId: albumId)
        }
        withAnimation(DesignAnim.crateColor) {
            current = newCrate
        }
    }

    /// Apply the override immediately (called from Settings picker).
    func applyOverride(index: Int) {
        setOverride(index: index)
        if index >= 0 && index < CRATE_COLORS.count {
            withAnimation(DesignAnim.crateColor) { current = CRATE_COLORS[index] }
        }
    }

    /// Switch back to auto — next track change will re-drive the color.
    func clearOverride() {
        setOverride(index: -1)
    }
}
