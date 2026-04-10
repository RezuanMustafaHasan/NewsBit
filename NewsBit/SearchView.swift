import SwiftUI
import FirebaseFirestore

struct SearchView: View {
    private enum SearchScope: String, CaseIterable, Identifiable {
        case news = "News"
        case users = "Users"

        var id: String { rawValue }
    }

    private struct SearchUserResult: Identifiable {
        let id: String
        let profileDocumentID: String
        let userUID: String?
        let username: String
        let email: String
        let gender: String
        let avatarColorHex: String
    }

    @StateObject private var newsViewModel = NewsFeedViewModel()
    @State private var selectedScope: SearchScope = .news
    @State private var query: String = ""

    @State private var userResults: [SearchUserResult] = []
    @State private var isUserSearchLoading = false
    @State private var userSearchError: String?
    @State private var userSearchTask: Task<Void, Never>?

    private let db = Firestore.firestore()

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedNewsQuery: String {
        trimmedQuery.precomposedStringWithCanonicalMapping
    }

    private var filteredNews: [NewsCard] {
        guard !normalizedNewsQuery.isEmpty else { return [] }

        return newsViewModel.cards.filter { card in
            matchesUnicode(card.title, query: normalizedNewsQuery)
                || matchesUnicode(card.source, query: normalizedNewsQuery)
                || matchesUnicode(card.summary, query: normalizedNewsQuery)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Search target", selection: $selectedScope) {
                    ForEach(SearchScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField(
                        selectedScope == .news
                            ? "Search news (বাংলা / English)"
                            : "Search user by name",
                        text: $query
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                    if !query.isEmpty {
                        Button {
                            query = ""
                            clearUserSearchState()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if selectedScope == .news {
                            newsSearchContent
                        } else {
                            userSearchContent
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Search")
            .task {
                await newsViewModel.loadInitialIfNeeded()
            }
            .onChange(of: selectedScope, initial: false) { _, newValue in
                if newValue == .users {
                    scheduleUserSearch()
                } else {
                    clearUserSearchState()
                }
            }
            .onChange(of: query, initial: false) { _, _ in
                if selectedScope == .users {
                    scheduleUserSearch()
                }
            }
        }
    }

    @ViewBuilder
    private var newsSearchContent: some View {
        if newsViewModel.isLoading && newsViewModel.cards.isEmpty {
            ProgressView("Loading news...")
                .frame(maxWidth: .infinity, alignment: .center)
        } else if let loadError = newsViewModel.loadError, newsViewModel.cards.isEmpty {
            Text(loadError)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if normalizedNewsQuery.isEmpty {
            Text("Search news by title, source, or summary.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if filteredNews.isEmpty {
            Text("No news found for \"\(trimmedQuery)\".")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            ForEach(filteredNews) { card in
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text("\(card.source) • \(card.time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(card.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemBackground))
                )
            }
        }
    }

    @ViewBuilder
    private var userSearchContent: some View {
        if trimmedQuery.isEmpty {
            Text("Search a user by name.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if isUserSearchLoading {
            ProgressView("Searching users...")
                .frame(maxWidth: .infinity, alignment: .center)
        } else if let userSearchError {
            Text(userSearchError)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if userResults.isEmpty {
            Text("No user found for \"\(trimmedQuery)\".")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            ForEach(userResults) { user in
                NavigationLink {
                    VisitedUserProfileView(
                        profileDocumentID: user.profileDocumentID,
                        userUID: user.userUID
                    )
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: user.avatarColorHex))
                            Text(userInitial(from: user.username))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.username)
                                .font(.headline)
                            Text(user.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Gender: \(user.gender)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemBackground))
                )
            }
        }
    }

    private func scheduleUserSearch() {
        userSearchTask?.cancel()
        clearUserSearchState()

        let name = trimmedQuery
        guard !name.isEmpty else { return }

        userSearchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await searchUsersByName(name)
        }
    }

    @MainActor
    private func searchUsersByName(_ name: String) async {
        isUserSearchLoading = true
        defer { isUserSearchLoading = false }

        do {
            let prefixSnapshot = try await db.collection("users")
                .order(by: "username")
                .start(at: [name])
                .end(at: [name + "\u{f8ff}"])
                .limit(to: 20)
                .getDocuments()

            var documents = prefixSnapshot.documents

            if documents.isEmpty {
                let fallbackSnapshot = try await db.collection("users")
                    .order(by: "username")
                    .limit(to: 100)
                    .getDocuments()
                documents = fallbackSnapshot.documents.filter { document in
                    let username = document.data()["username"] as? String ?? ""
                    return username.range(
                        of: name,
                        options: [.caseInsensitive, .diacriticInsensitive],
                        locale: .current
                    ) != nil
                }
            }

            userResults = documents.map { document in
                let data = document.data()
                let profileDocumentID = document.documentID
                let userUID = data["uid"] as? String
                return SearchUserResult(
                    id: profileDocumentID,
                    profileDocumentID: profileDocumentID,
                    userUID: userUID,
                    username: data["username"] as? String ?? "Unknown",
                    email: data["email"] as? String ?? "-",
                    gender: data["gender"] as? String ?? "Unknown",
                    avatarColorHex: data["avatarColorHex"] as? String ?? "#0984E3"
                )
            }
            userSearchError = nil
        } catch {
            userResults = []
            userSearchError = "Unable to search users right now."
        }
    }

    private func clearUserSearchState() {
        userResults = []
        userSearchError = nil
        isUserSearchLoading = false
    }

    private func userInitial(from username: String) -> String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "U" }
        return String(first).uppercased()
    }

    private func matchesUnicode(_ source: String, query: String) -> Bool {
        let normalizedSource = source.precomposedStringWithCanonicalMapping
        if normalizedSource.contains(query) {
            return true
        }

        return normalizedSource.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        ) != nil
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }
}
