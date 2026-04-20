import SwiftUI

struct ArtistRowView: View {
    let artist: ArtistID3
    @State private var imageURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                avatar

                Text(artist.name)
                    .font(.system(size: 38 / 2, weight: .medium, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.leading, 16)
            .padding(.trailing, 30)
            .frame(minHeight: 72)

            Rectangle()
                .fill(Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255))
                .frame(height: 0.5)
                .padding(.leading, 80)
                .padding(.trailing, 30)
        }
        .background(Color.black)
        .task(id: artist.id) {
            guard imageURL == nil else { return }
            do {
                let info = try await NavidromeClient.shared.getArtistInfo2(id: artist.id)
                if let rawURL = info.imageURL {
                    imageURL = URL(string: rawURL)
                }
            } catch {
                imageURL = nil
            }
        }
    }

    private var avatar: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderAvatar
                    }
                }
            } else {
                placeholderAvatar
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
        .overlay {
            Circle().stroke(Color.black.opacity(0.15), lineWidth: 0.5)
        }
    }

    private var placeholderAvatar: some View {
        ZStack {
            Circle()
                .fill(Color(red: 58 / 255, green: 58 / 255, blue: 60 / 255))

            Image(systemName: isUnknownArtist ? "star.fill" : "music.note")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(white: 0.82))
        }
    }

    private var isUnknownArtist: Bool {
        artist.name.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare("[Unknown Artist]") == .orderedSame
    }
}
