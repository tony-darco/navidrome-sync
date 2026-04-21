// ClickWheelView.swift
// navidrome-sync — Retro iPod click wheel control.
// Crate-colored: outer ring, inner ring, center button all follow crate tokens.
// Gesture classification:
//   • Tap within ringInnerFraction of radius → center → play/pause
//   • Tap in outer quadrant:  top → onTopTap, bottom → onBottomTap,
//                             left → onLeftTap, right → onRightTap
//   • Drag in ring zone → onScrub(fraction) where fraction 0.0–1.0

import SwiftUI

struct ClickWheelView: View {
    let crate: CrateColorSet

    // Action callbacks
    var onCenterTap:  () -> Void = {}
    var onTopTap:     () -> Void = {}
    var onBottomTap:  () -> Void = {}
    var onLeftTap:    () -> Void = {}
    var onRightTap:   () -> Void = {}
    /// Called repeatedly while dragging; fraction is angular position 0.0–1.0
    var onScrub: (Double) -> Void = { _ in }

    // Internal drag state
    @State private var lastAngle: Double? = nil
    @State private var accumulatedAngle: Double = 0
    @State private var isDragging = false
    @State private var centerPressed = false

    private let diameter: CGFloat = DesignDim.wheelDiameter
    private var radius:   CGFloat { diameter / 2 }

    var body: some View {
        ZStack {
            // ── Outer ring ─────────────────────────────────────────────
            Circle()
                .fill(crate.outer)
                .frame(width: diameter, height: diameter)

            // ── Inner ring ─────────────────────────────────────────────
            Circle()
                .fill(crate.ring)
                .frame(width: diameter - DesignDim.wheelRingInset * 2,
                       height: diameter - DesignDim.wheelRingInset * 2)

            // ── Quadrant labels ────────────────────────────────────────
            let labelOffset = radius * 0.68
            Group {
                Text(DesignWheel.top)
                    .offset(y: -labelOffset)
                Text(DesignWheel.bottom)
                    .offset(y:  labelOffset)
                Text(DesignWheel.left)
                    .offset(x: -labelOffset)
                Text(DesignWheel.right)
                    .offset(x:  labelOffset)
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(crate.text)

            // ── Center button ──────────────────────────────────────────
            Circle()
                .fill(crate.center)
                .frame(width: DesignDim.wheelCenterInset * 2,
                       height: DesignDim.wheelCenterInset * 2)
                .overlay(
                    Circle()
                        .fill(crate.inner)
                        .frame(width: DesignDim.wheelCenterInner,
                               height: DesignDim.wheelCenterInner)
                )
                .scaleEffect(centerPressed ? 0.92 : 1.0)
                .animation(DesignAnim.rowPress, value: centerPressed)
        }
        .frame(width: diameter, height: diameter)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    let loc = value.location
                    let center = CGPoint(x: diameter / 2, y: diameter / 2)
                    let dx = loc.x - center.x
                    let dy = loc.y - center.y
                    let dist = hypot(dx, dy)
                    let innerThreshold = radius * DesignDim.ringInnerFraction
                    let outerThreshold = radius * DesignDim.ringOuterFraction

                    if dist < innerThreshold {
                        // Hovering over center button
                        if !isDragging { centerPressed = true }
                    } else if dist <= outerThreshold {
                        // Ring drag — accumulate angle for scrubbing
                        isDragging = true
                        centerPressed = false
                        let angle = atan2(dy, dx) // -π to π
                        if let prev = lastAngle {
                            var delta = angle - prev
                            // Wrap around discontinuity
                            if delta > .pi  { delta -= 2 * .pi }
                            if delta < -.pi { delta += 2 * .pi }
                            accumulatedAngle += delta
                        }
                        lastAngle = angle
                        // Map accumulated rotation to 0–1 fraction (one full rotation = 2π)
                        let fraction = max(0, min(1, (accumulatedAngle / (.pi * 2) + 0.5)))
                        onScrub(fraction)
                    }
                }
                .onEnded { value in
                    let loc = value.location
                    let center = CGPoint(x: diameter / 2, y: diameter / 2)
                    let dx = loc.x - center.x
                    let dy = loc.y - center.y
                    let dist = hypot(dx, dy)
                    let innerThreshold = radius * DesignDim.ringInnerFraction
                    let outerThreshold = radius * DesignDim.ringOuterFraction
                    let dragDistance = hypot(value.translation.width, value.translation.height)

                    centerPressed = false

                    // Only fire taps if not a significant drag
                    if dragDistance < 6 {
                        if dist < innerThreshold {
                            onCenterTap()
                        } else if dist <= outerThreshold {
                            // Classify quadrant by angle
                            let angle = atan2(dy, dx) // -π to π, right=0, down=π/2
                            let deg = angle * 180 / .pi
                            if deg > -45 && deg <= 45 {
                                onRightTap()
                            } else if deg > 45 && deg <= 135 {
                                onBottomTap()
                            } else if (deg > 135 && deg <= 180) || (deg >= -180 && deg <= -135) {
                                onLeftTap()
                            } else {
                                onTopTap()
                            }
                        }
                    }

                    isDragging = false
                    lastAngle = nil
                    // Reset accumulated angle so next drag starts fresh
                    accumulatedAngle = 0
                }
        )
    }
}

#Preview {
    ZStack {
        Color(hex: "#F5D898")
        ClickWheelView(
            crate: CRATE_COLORS[1],
            onCenterTap:  { print("center") },
            onTopTap:     { print("top") },
            onBottomTap:  { print("bottom") },
            onLeftTap:    { print("left") },
            onRightTap:   { print("right") },
            onScrub:      { print("scrub \($0)") }
        )
    }
    .frame(width: 300, height: 300)
}
