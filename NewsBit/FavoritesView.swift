import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
struct FavoritesView: View {
    @StateObject private var viewModel: FavoritesViewModel
    @State private var selectedCard: NewsCard?
    @State private var isShowingDetail = false

    init(userID: String?) {
        _viewModel = StateObject(wrappedValue: FavoritesViewModel(userID: userID))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView("Loading favorites...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 10) {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task {
                                await viewModel.loadFavorites()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.items.isEmpty {
                    Text("No favorite news yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            FavoriteRow(
                                item: item,
                                onTap: {
                                    Task {
                                        let card = await viewModel.fetchNewsDetails(for: item)
                                        selectedCard = card
                                        isShowingDetail = true
                                    }
                                }
                            ) {
                                Task {
                                    await viewModel.unfavorite(itemID: item.id)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Favorites")
            .task {
                await viewModel.loadFavorites()
            }
            .navigationDestination(isPresented: $isShowingDetail) {
                if let selectedCard {
                    NewsDetailView(card: selectedCard)
                }
            }
            .refreshable {
                await viewModel.loadFavorites()
            }
        }
    }
}

private struct FavoriteRow: View {
    let item: FavoriteNewsItem
    let onTap: () -> Void
    let onUnfavorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(item.dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onUnfavorite) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.red)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let imageURL = item.imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    placeholderThumbnail
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            placeholderThumbnail
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var placeholderThumbnail: some View {
        ZStack {
            LinearGradient(colors: [.blue, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "newspaper.fill")
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

struct FavoriteNewsItem: Identifiable, Hashable {
    let id: String
    let title: String
    let date: Date
    let source: String
    let timeText: String
    let summary: String
    let fullText: String
    let thumbnailSymbol: String
    let imageURL: URL?

    var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var asNewsCard: NewsCard {
        NewsCard(
            id: id,
            source: source,
            title: title,
            time: timeText,
            summary: summary,
            fullText: fullText,
            commentCount: 0,
            imageURL: imageURL,
            thumbnailSymbol: thumbnailSymbol,
            imageGradient: LinearGradient(
                colors: [.blue, .mint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published private(set) var items: [FavoriteNewsItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let db = Firestore.firestore()
    private let service = NewsFeedService()
    private let userID: String?

    init(userID: String?) {
        self.userID = userID
    }

    func loadFavorites() async {
        guard let userID, !userID.isEmpty else {
            items = []
            errorMessage = "You need to be signed in to view favorites."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection("favorites")
                .whereField("userID", isEqualTo: userID)
                .getDocuments()

            let mappedItems = snapshot.documents.map { document in
                let data = document.data()
                let newsID = data["newsId"] as? String ?? document.documentID
                let title = data["title"] as? String ?? "Untitled"
                let source = data["source"] as? String ?? "NewsBit"
                let timeText = data["timeText"] as? String ?? "Saved"
                let summary = data["summary"] as? String ?? "No summary available."
                let fullText = data["fullText"] as? String ?? summary
                let thumbnailSymbol = data["thumbnailSymbol"] as? String ?? "newspaper.fill"
                let savedAt = (data["savedAt"] as? Timestamp)?.dateValue() ?? Date()
                let rawImageURL = data["imageURL"] as? String
                let imageURL = rawImageURL.flatMap(URL.init(string:))

                return FavoriteNewsItem(
                    id: newsID,
                    title: title,
                    date: savedAt,
                    source: source,
                    timeText: timeText,
                    summary: summary,
                    fullText: fullText,
                    thumbnailSymbol: thumbnailSymbol,
                    imageURL: imageURL
                )
            }
            items = mappedItems.sorted { $0.date > $1.date }
        } catch {
            errorMessage = "Unable to load favorites right now."
        }
    }

    func unfavorite(itemID: String) async {
        guard let userID, !userID.isEmpty else { return }
        let entryID = "\(userID)_\(itemID)"

        let originalItems = items
        items.removeAll { $0.id == itemID }

        do {
            try await db.collection("favorites")
                .document(entryID)
                .delete()
        } catch {
            items = originalItems
            errorMessage = "Unable to remove favorite right now."
        }
    }

    func fetchNewsDetails(for item: FavoriteNewsItem) async -> NewsCard {
        do {
            if let fetchedCard = try await service.fetchCard(matching: item.id) {
                return fetchedCard
            }
        } catch {
            // Fall back to persisted favorite data if live fetch fails.
        }

        return item.asNewsCard
    }
}
