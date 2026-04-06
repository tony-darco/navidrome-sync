import SwiftUI

struct AlphabetScrubber: View {
    let letters: [String]
    @Binding var selectedLetter: String?

    var body: some View {
        VStack(spacing: 2) {
            ForEach(letters, id: \.self) { letter in
                Text(letter)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(selectedLetter == letter ? Color.accentColor : .secondary)
                    .onTapGesture {
                        selectedLetter = letter
                    }
            }
        }
        .padding(.trailing, 4)
    }
}
