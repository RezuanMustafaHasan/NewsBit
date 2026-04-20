import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
struct FavoritesView: View {
    @StateObject private var viewModel: FavoritesViewModel
    @State private var selectedCard: NewsCard?
    @State private var isShowingDetail = false
    @State private var pendingUndoItem: FavoriteNewsItem?
    @State private var undoDismissTask: Task<Void, Never>?

    init(userID: String?) {
        _viewModel = StateObject(wrappedValue: FavoritesViewModel(userID: userID))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumHomeBackground()

                favoritesContent
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadFavorites()
            }
            .navigationDestination(isPresented: $isShowingDetail) {
                if let selectedCard {
                    NewsDetailView(card: selectedCard)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let pendingUndoItem {
                Button("Undo") {
                    Task {
                        let restored = await viewModel.restoreFavorite(item: pendingUndoItem)
                        if restored {
                            hideUndo()
                        }
                    }
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(HomePalette.accent)
                .homeGlassCard(cornerRadius: 20)
                .padding(.trailing, 16)
                .padding(.bottom, 22)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: pendingUndoItem?.id)
    }

    @ViewBuilder
    private var favoritesContent: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            progressState("Loading favorites...")
        } else if let errorMessage = viewModel.errorMessage {
            statusCard(
                title: "Unable to load favorites",
                subtitle: errorMessage,
                actionTitle: "Retry"
            ) {
                Task {
                    await viewModel.loadFavorites()
                }
            }
        } else if viewModel.items.isEmpty {
            statusCard(
                title: "No favorite news yet",
                subtitle: "Stories you save will appear here for quick reading later."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
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
                                let didUnfavorite = await viewModel.unfavorite(item: item)
                                if didUnfavorite {
                                    showUndo(for: item)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await viewModel.loadFavorites()
            }
        }
    }

    private func progressState(_ title: String) -> some View {
        VStack {
            ProgressView(title)
                .tint(HomePalette.accent)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .homeGlassCard(cornerRadius: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private func statusCard(
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(HomePalette.primaryText)

            Text(subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(HomePalette.mutedText)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(HomePalette.accent)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .homeGlassCard(cornerRadius: 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func showUndo(for item: FavoriteNewsItem) {
        undoDismissTask?.cancel()
        pendingUndoItem = item
        undoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    hideUndo()
                }
            }
        }
    }

    private func hideUndo() {
        undoDismissTask?.cancel()
        undoDismissTask = nil
        pendingUndoItem = nil
    }
}

private struct FavoriteRow: View {
    let item: FavoriteNewsItem
    let onTap: () -> Void
    let onUnfavorite: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(HomePalette.primaryText)
                    .lineLimit(3)

                VStack(alignment: .leading, spacing: 6) {
                    Label(item.dateText, systemImage: "clock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HomePalette.mutedText)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label(item.source, systemImage: "newspaper")
                            .font(.caption)
                            .foregroundStyle(HomePalette.mutedText)
                            .lineLimit(1)

                        Text(item.timeText)
                            .font(.caption)
                            .foregroundStyle(HomePalette.mutedText)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Button(action: onUnfavorite) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.96))
                    )
                    .overlay(
                        Circle()
                            .stroke(HomePalette.softStroke, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(HomePalette.softStroke, lineWidth: 1)
                )
                .shadow(color: HomePalette.shadow, radius: 16, x: 0, y: 10)
        )
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
            .frame(width: 82, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            placeholderThumbnail
                .frame(width: 82, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    func unfavorite(item: FavoriteNewsItem) async -> Bool {
        guard let userID, !userID.isEmpty else { return false }
        let entryID = "\(userID)_\(item.id)"

        let originalItems = items
        items.removeAll { $0.id == item.id }

        do {
            try await db.collection("favorites")
                .document(entryID)
                .delete()
            return true
        } catch {
            items = originalItems
            errorMessage = "Unable to remove favorite right now."
            return false
        }
    }

    func restoreFavorite(item: FavoriteNewsItem) async -> Bool {
        guard let userID, !userID.isEmpty else { return false }
        let entryID = "\(userID)_\(item.id)"

        do {
            try await db.collection("favorites")
                .document(entryID)
                .setData([
                    "entryId": entryID,
                    "userID": userID,
                    "newsId": item.id,
                    "title": item.title,
                    "source": item.source,
                    "timeText": item.timeText,
                    "summary": item.summary,
                    "fullText": item.fullText,
                    "thumbnailSymbol": item.thumbnailSymbol,
                    "imageURL": item.imageURL?.absoluteString ?? "",
                    "savedAt": Timestamp(date: item.date)
                ], merge: true)

            if !items.contains(where: { $0.id == item.id }) {
                items.append(item)
                items.sort { $0.date > $1.date }
            }
            return true
        } catch {
            errorMessage = "Unable to restore favorite right now."
            return false
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
