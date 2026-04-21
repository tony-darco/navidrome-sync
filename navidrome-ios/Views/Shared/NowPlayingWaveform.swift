import SwiftUI

// Animated waveform bars shown over currently-playing songs.
struct WaveformBarsView: View {
    let isAnimating: Bool
    var color: Color = .white

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            WaveformBar(maxHeight: 14, duration: 0.5, isAnimating: isAnimating, color: color)
            WaveformBar(maxHeight: 10, duration: 0.7, isAnimating: isAnimating, color: color)
            WaveformBar(maxHeight: 12, duration: 0.4, isAnimating: isAnimating, color: color)
        }
        .frame(width: 16, height: 16)
    }
}

private struct WaveformBar: View {
    let maxHeight: CGFloat
    let duration: Double
    let isAnimating: Bool
    let color: Color

    @State private var height: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .frame(width: 3, height: height)
            .onAppear { apply(isAnimating) }
            .onChange(of: isAnimating) { _, on in apply(on) }
    }

    private func apply(_ on: Bool) {
        if on {
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                height = maxHeight
            }
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                height = 5
            }
        }
    }
}

// Semi-transparent dark overlay + waveform, placed over cover art.
struct NowPlayingOverlay: View {
    let isNowPlaying: Bool
    let isPlaying: Bool

    var body: some View {
        if isNowPlaying {
            ZStack {
                Color.black.opacity(0.45)
                WaveformBarsView(isAnimating: isPlaying)
            }
        }
    }
}
