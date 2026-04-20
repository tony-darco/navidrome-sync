import SwiftUI

struct AlphabetScrubber: View {
    let letters: [String]
    let activeLetters: Set<String>
    @Binding var selectedLetter: String?
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ForEach(letters, id: \.self) { letter in
                    Text(letter)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(letterColor(for: letter))
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedLetter = letter
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        updateSelection(for: value.location.y, height: geometry.size.height)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(width: 18)
        .frame(maxHeight: .infinity)
        .background {
            if isDragging {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            }
        }
        .animation(.easeOut(duration: 0.15), value: isDragging)
    }

    private func updateSelection(for y: CGFloat, height: CGFloat) {
        guard !letters.isEmpty, height > 0 else { return }
        let clampedY = min(max(y, 0), max(height - 1, 0))
        let itemHeight = height / CGFloat(letters.count)
        let rawIndex = Int(clampedY / max(itemHeight, 1))
        let index = min(max(rawIndex, 0), letters.count - 1)
        let letter = letters[index]
        if selectedLetter != letter {
            selectedLetter = letter
        }
    }

    private func letterColor(for letter: String) -> Color {
        if selectedLetter == letter {
            return Color(red: 64 / 255, green: 156 / 255, blue: 255 / 255)
        }
        return activeLetters.contains(letter) ? Color(white: 0.58) : Color(white: 0.38)
    }
}
