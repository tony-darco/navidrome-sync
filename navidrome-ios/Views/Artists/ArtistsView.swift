import SwiftUI

enum ArtistSortOrder: String, CaseIterable {
    case alphabetical
    case reverseAlphabetical
    case mostAlbums

    var label: String {
        switch self {
        case .alphabetical: "A to Z"
        case .reverseAlphabetical: "Z to A"
        case .mostAlbums: "Most Albums"
        }
    }

    var icon: String {
        switch self {
        case .alphabetical: "textformat.abc"
        case .reverseAlphabetical: "textformat.abc.dottedunderline"
        case .mostAlbums: "square.stack.3d.up"
        }
    }
}

enum ArtistFilterOption: String, CaseIterable {
    case all
    case hideUnknown
    case twoOrMoreAlbums

    var label: String {
        switch self {
        case .all: "All Artists"
        case .hideUnknown: "Hide Unknown Artist"
        case .twoOrMoreAlbums: "2+ Albums"
        }
    }
}

private struct ArtistSection: Identifiable {
    let name: String
    let artists: [ArtistID3]

    var id: String { name }
}

struct ArtistsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var artistIndexes: [ArtistIndex] = []
    @State private var isLoading = false
    @State private var selectedLetter: String?
    @State private var searchText = ""
    @State private var sortOrder: ArtistSortOrder = .alphabetical
    @State private var filterOption: ArtistFilterOption = .all

    private let indexLetters = ["#"] + (65...90).compactMap { UnicodeScalar($0) }.map { String(Character($0)) }

    private var availableLetters: [String] {
        displayedSections.map(\.name)
    }

    private var flattenedArtists: [ArtistID3] {
        artistIndexes.flatMap(\.artist)
    }

    private var displayedSections: [ArtistSection] {
        let filteredByName: [ArtistID3] = if searchText.isEmpty {
            flattenedArtists
        } else {
            flattenedArtists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        let filteredByOption: [ArtistID3]
        switch filterOption {
        case .all:
            filteredByOption = filteredByName
        case .hideUnknown:
            filteredByOption = filteredByName.filter {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare("[Unknown Artist]") != .orderedSame
            }
        case .twoOrMoreAlbums:
            filteredByOption = filteredByName.filter { $0.albumCount >= 2 }
        }

        let sorted: [ArtistID3]
        switch sortOrder {
        case .alphabetical:
            sorted = filteredByOption.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .reverseAlphabetical:
            sorted = filteredByOption.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending
            }
        case .mostAlbums:
            sorted = filteredByOption.sorted {
                if $0.albumCount == $1.albumCount {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.albumCount > $1.albumCount
            }
        }

        let grouped = Dictionary(grouping: sorted, by: sectionKey(for:))
        let keys = grouped.keys.sorted(by: sectionSort)
        return keys.map { key in
            let sectionArtists = grouped[key] ?? []
            return ArtistSection(name: key, artists: sectionArtists)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            topBar
                .padding(.horizontal, 16)

            searchBar
                .padding(.horizontal, 16)

            ScrollViewReader { proxy in
                ZStack(alignment: .trailing) {
                    List {
                        ForEach(displayedSections) { section in
                            Section(header: sectionHeader(for: section.name).id(section.name)) {
                                ForEach(section.artists) { artist in
                                    ArtistRowView(artist: artist)
                                        .background {
                                            NavigationLink(value: artist) { EmptyView() }.opacity(0)
                                        }
                                        .listRowInsets(EdgeInsets())
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.black)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollIndicators(.hidden)
                    .scrollContentBackground(.hidden)
                    .background(Color.black)
                    .onChange(of: selectedLetter) { _, newValue in
                        guard let letter = newValue else { return }
                        guard let target = nearestSection(for: letter) else { return }
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                    }
                    .overlay {
                        if !isLoading && displayedSections.isEmpty {
                            ContentUnavailableView(
                                "No Artists",
                                systemImage: "music.mic",
                                description: Text("Try adjusting search or filter options.")
                            )
                        }
                    }

                    if !availableLetters.isEmpty {
                        AlphabetScrubber(
                            letters: indexLetters,
                            activeLetters: Set(availableLetters),
                            selectedLetter: $selectedLetter
                        )
                            .padding(.trailing, 4)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(.top, 8)
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            if isLoading && artistIndexes.isEmpty {
                ProgressView()
            }
        }
        .task {
            await loadArtists()
        }
    }

    private func loadArtists() async {
        guard artistIndexes.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            artistIndexes = try await NavidromeClient.shared.getArtists()
        } catch {
            print("[artists] failed to load: \(error)")
        }
    }

    private func sectionHeader(for title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(Color(white: 0.55))
            Spacer()
        }
        .padding(.leading, 16)
        .padding(.trailing, 30)
        .padding(.vertical, 6)
        .listRowInsets(EdgeInsets())
        .background(.ultraThinMaterial.opacity(0.8))
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color(white: 0.64))

            TextField("Search", text: $searchText)
                .font(.system(size: 16, weight: .regular, design: .default))
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255))
                    .clipShape(Circle())
            }

            Spacer()

            Text("Artists")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 2) {
                Menu {
                    Section("Sort") {
                        ForEach(ArtistSortOrder.allCases, id: \.self) { option in
                            Button {
                                sortOrder = option
                            } label: {
                                Label(option.label, systemImage: option.icon)
                            }
                        }
                    }

                    Section("Filter") {
                        ForEach(ArtistFilterOption.allCases, id: \.self) { option in
                            Button {
                                filterOption = option
                            } label: {
                                if filterOption == option {
                                    Label(option.label, systemImage: "checkmark")
                                } else {
                                    Text(option.label)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 30, height: 30)
                }

                Menu {
                    Button {
                        searchText = ""
                        filterOption = .all
                        sortOrder = .alphabetical
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }

                    Button {
                        Task {
                            artistIndexes = []
                            await loadArtists()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 30, height: 30)
                }
            }
            .foregroundStyle(Color(red: 64 / 255, green: 156 / 255, blue: 255 / 255))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    private func sectionKey(for artist: ArtistID3) -> String {
        let trimmed = artist.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "#" }
        let upper = String(first).uppercased()
        if upper.range(of: "[A-Z]", options: .regularExpression) != nil {
            return upper
        }
        return "#"
    }

    private func sectionSort(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == "#" { return true }
        if rhs == "#" { return false }
        return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }

    private func nearestSection(for letter: String) -> String? {
        guard !availableLetters.isEmpty else { return nil }
        guard !availableLetters.contains(letter) else { return letter }
        guard let selectedIndex = indexLetters.firstIndex(of: letter) else { return availableLetters.first }

        let availableIndexValues = availableLetters.compactMap { section in
            indexLetters.firstIndex(of: section)
        }
        if let nextIndex = availableIndexValues.filter({ $0 >= selectedIndex }).min() {
            return indexLetters[nextIndex]
        }
        if let previousIndex = availableIndexValues.filter({ $0 < selectedIndex }).max() {
            return indexLetters[previousIndex]
        }
        return availableLetters.first
    }
}
